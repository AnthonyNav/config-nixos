#!/usr/bin/env python3
"""Reconcile only fleet-owned entries; never import local settings into Nix."""
import argparse
import copy
import json
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import tomllib

START = "# BEGIN nixos-fleet-ai"
END = "# END nixos-fleet-ai"


def read(path):
    if path.is_symlink():
        raise ValueError(f"Refusing mutable integration through symlink: {path}")
    if path.exists() and not path.is_file():
        raise ValueError(f"Expected regular file: {path}")
    return path.read_text() if path.exists() else ""


def parent_at(data, keys):
    for key in keys:
        data = data.setdefault(key, {})
        if not isinstance(data, dict):
            raise ValueError("Expected an object in configuration")
    return data


def merge_json(raw, previous, desired):
    data = json.loads(raw) if raw.strip() else {}
    if not isinstance(data, dict):
        raise ValueError("Expected a JSON object")
    for entry in previous:
        parent = parent_at(data, entry["path"][:-1])
        key = entry["path"][-1]
        if entry["kind"] == "append":
            values = parent.get(key, [])
            if not isinstance(values, list):
                raise ValueError("Expected a hook array")
            remaining = [v for v in values if v not in entry["value"]]
            if not remaining and entry.get("created", False):
                parent.pop(key, None)
            else:
                parent[key] = remaining
        elif key in parent:
            if parent[key] != entry["value"]:
                raise ValueError("A fleet-owned MCP entry was modified locally; reconcile it first")
            del parent[key]
    for entry in desired:
        parent = parent_at(data, entry["path"][:-1])
        key = entry["path"][-1]
        if entry["kind"] == "append":
            values = parent.setdefault(key, [])
            if not isinstance(values, list):
                raise ValueError("Expected a hook array")
            values.extend(v for v in entry["value"] if v not in values)
        else:
            if key in parent and parent[key] != entry["value"]:
                raise ValueError("MCP ID conflicts with user configuration")
            parent[key] = copy.deepcopy(entry["value"])
    return json.dumps(data, indent=2, ensure_ascii=False) + "\n"


def merge_text(raw, previous, desired, is_toml=False):
    # Validate before removing the owned block. Malformed files remain untouched.
    if is_toml:
        tomllib.loads(raw)
    if raw.count(START) != raw.count(END) or raw.count(START) > 1:
        raise ValueError("Malformed fleet context/config markers")
    if START in raw:
        first, tail = raw.split(START, 1)
        owned, last = tail.split(END, 1)
        if previous is None or owned.strip() != previous.strip():
            raise ValueError("Fleet-managed text was edited locally")
        raw = first + last.lstrip("\n")
    result = raw
    if desired:
        result = raw.rstrip("\n") + ("\n\n" if raw else "") + START + "\n" + desired.rstrip() + "\n" + END + "\n"
    if is_toml:
        tomllib.loads(result)  # Duplicate MCP tables are conflicts, not overwrites.
    return result


def atomic_write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=".fleet-ai-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(content)
        os.chmod(name, 0o600)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def record_append_ownership(home, previous, manifest):
    """Record presence only, so disabling restores user-owned empty hook arrays."""
    recorded = copy.deepcopy(manifest)
    for relative, entries in recorded.get("json", {}).items():
        original = json.loads(read(home / relative) or "{}")
        old = previous.get("json", {}).get(relative, [])
        for entry in entries:
            if entry["kind"] != "append":
                continue
            prior = next((value for value in old if value["kind"] == "append" and value["path"] == entry["path"]), None)
            if prior is not None:
                entry["created"] = prior.get("created", False)  # Legacy state is conservative.
                continue
            parent = original
            for key in entry["path"][:-1]:
                parent = parent.get(key, {}) if isinstance(parent, dict) else {}
            entry["created"] = entry["path"][-1] not in parent
    return recorded


def declared_manifest(recorded):
    result = copy.deepcopy(recorded)
    for entries in result.get("json", {}).values():
        for entry in entries:
            entry.pop("created", None)
    return result


def plan(home, previous, desired):
    result = []
    for kind in ("json", "text"):
        before = previous.get(kind, {})
        after = desired.get(kind, {})
        for rel in sorted(before.keys() | after.keys()):
            relative = Path(rel)
            if relative.is_absolute() or ".." in relative.parts:
                raise ValueError("Integration paths must stay below the declared home")
            path = home / relative
            # Also reject symlinked ancestor directories to avoid writing elsewhere.
            for ancestor in path.parents:
                if ancestor == home:
                    break
                if ancestor.is_symlink():
                    raise ValueError(f"Symlinked integration directory: {ancestor}")
            raw = read(path)
            if kind == "json":
                updated = merge_json(raw, before.get(rel, []), after.get(rel, []))
            else:
                updated = merge_text(raw, before.get(rel), after.get(rel), rel.endswith(".toml"))
            if updated != raw:
                result.append((path, raw, updated))
    return result


def reconcile(home, manifest, check):
    state = home / ".local/state/nixos-ai/ownership.json"
    for ancestor in state.parents:
        if ancestor == home:
            break
        if ancestor.is_symlink():
            raise ValueError("Symlinked ownership directory")
    previous = json.loads(read(state) or "{}")
    changes = plan(home, previous, manifest)  # Validate ALL targets before writing.
    recorded = record_append_ownership(home, previous, manifest)
    for path, _, _ in changes:
        if path.with_name(path.name + ".fleet-ai-backup").is_symlink():
            raise ValueError("Symlinked backup")
    if check:
        return
    written = []
    try:
        for path, raw, updated in changes:
            if read(path) != raw:
                raise ValueError(f"Configuration changed during activation: {path}")
            existed = path.exists()
            if existed:
                backup = path.with_name(path.name + ".fleet-ai-backup")
                atomic_write(backup, raw)
            atomic_write(path, updated)
            written.append((path, raw, updated, existed))
        atomic_write(state, json.dumps(recorded, indent=2) + "\n")
    except (ValueError, OSError):
        for path, raw, updated, existed in reversed(written):
            # Preserve concurrent user edits rather than overwriting them.
            if read(path) == updated:
                if existed:
                    atomic_write(path, raw)
                else:
                    path.unlink()
        raise


def information(home, bundle):
    """Credential-free diagnostics; eligibility never implies a running service."""
    spec = importlib.util.spec_from_file_location("workspace_identity", Path(__file__).with_name("workspace-context.py"))
    identity = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(identity)
    spec = importlib.util.spec_from_file_location("portable_workspace", Path(__file__).with_name("workspace.py"))
    portable = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(portable)
    config = json.loads((bundle / "workspace-policy.json").read_text())
    info = identity.resolve(config)
    binaries = {name: shutil.which(name) for name in ("codex", "claude", "kiro-cli", "opencode", "orca-ide", "agy", "bwrap", "socat", "nsjail")}
    warnings = []
    for agent, required in (("codex", ("bwrap",)), ("claude", ("bwrap", "socat")), ("agy", ("nsjail",))):
        if binaries[agent]:
            for binary in required:
                if not binaries[binary]:
                    warnings.append(f"{agent}: missing Linux sandbox dependency {binary}")
    return {
        "schema_version": 1,
        "host": json.loads((bundle / "host.json").read_text()),
        "context": info["context"],
        "directory": info["directory"],
        "git_common_dir": info["git_common_dir"],
        "workspace": portable.snapshot(config, info["workspace"]),
        "skills": sorted(path.parent.name for path in (bundle / "skills").glob("*/SKILL.md")),
        "binaries": binaries,
        "sandbox": {
            "codex": {"backend": "bubblewrap", "dependencies_available": bool(binaries["bwrap"]), "runtime_verified": False},
            "claude": {"backend": "native Bash sandbox", "dependencies_available": bool(binaries["bwrap"] and binaries["socat"]), "runtime_verified": False},
            "antigravity": {"applicable": bool(binaries["agy"]), "dependencies_available": bool(binaries["nsjail"]) if binaries["agy"] else None, "runtime_verified": False},
            "opencode": {"backend": "permission policy", "os_isolation_claimed": False},
            "kiro": {"backend": "local permission/trust policy", "os_isolation_claimed": False},
        },
        "orca_runtime_status": "not probed; availability/policy do not imply a running runtime",
        "warnings": warnings,
    }


def doctor(home, bundle):
    facts = json.loads((bundle / "host.json").read_text())
    registry = json.loads((bundle / "registry.json").read_text())
    manifest = json.loads((bundle / "manifest.json").read_text())
    print(f'Host: {facts["host"]} | {facts["platform"]} | {facts["kind"]}')
    policy = bundle / "workspace-policy.json"
    if policy.exists():
        spec = importlib.util.spec_from_file_location("workspace", Path(__file__).with_name("workspace-context.py"))
        workspace = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(workspace)
        configuration = json.loads(policy.read_text())
        info = workspace.resolve(configuration)
        print("Workspace: " + json.dumps(workspace.status(configuration, info)))
        allowed = [entry["id"] for entry in registry if entry["context"] in ("any", info["context"])]
        print("MCP eligible in this context (enablement remains separate): " + ", ".join(allowed))
    failures = []
    for binary in ("codex", "claude", "kiro-cli", "opencode", "rtk"):
        present = shutil.which(binary) is not None
        print(f'{binary}: {"available" if present else "MISSING"}')
        if not present:
            failures.append(binary)
    print(f'Canonical skills: {len(list((bundle / "skills").glob("*/SKILL.md")))}')
    for name in ("orca-cli", "orchestration", "computer-use", "orca-emulator-android"):
        path = home / ".agents/skills" / name / "SKILL.md"
        print(f'Orca skill {name}: {"not installed" if not path.exists() else "read-only link; needs owner review" if path.is_symlink() else "mutable local stub"}')
    for binary in ("orca-ide", "postman", "posting", "hurl", "tofu", "terragrunt", "kubectl", "helm", "k9s", "kustomize", "kubectx", "kubens", "stern", "trivy", "syft", "grype", "cosign", "dive", "gitleaks", "sops", "age", "nmap", "mtr", "iperf3", "dig", "host", "tcpdump", "fd", "yq", "just", "watchexec", "hyperfine", "nvd"):
        print(f'{binary}: {shutil.which(binary) or "not selected/present"}')
    runtime = information(home, bundle)
    print("Workspace handoff: " + json.dumps(runtime["workspace"]))
    print("Orca Remote policy: " + json.dumps(facts.get("orcaRemote", {})) + " (runtime not probed)")
    failures.extend(runtime["warnings"])
    print("Sandbox dependencies: " + json.dumps(runtime["sandbox"]) + " (verify the agents' effective native modes separately)")
    print("Managed Syncthing roots: fleet-work/personal -> ~/Workspace/{work,personal}; project HANDOFF/docs/assets plus legacy shared/")
    print("Postman: fleet wrapper provides GTK schemas; GUI health requires a deployed session")
    print(f'MCP catalog: {len(registry)}; enabled: ' + json.dumps(json.loads((bundle / "enabled.json").read_text())))
    try:
        previous = json.loads(read(home / ".local/state/nixos-ai/ownership.json") or "{}")
        pending = plan(home, previous, manifest)
        if pending or declared_manifest(previous) != manifest:
            failures.append("integration missing or drifted; activate reviewed main to reconcile")
    except (ValueError, OSError) as exc:
        failures.append(str(exc))
    for relative in json.loads((bundle / "files.json").read_text()):
        if not (home / relative).exists():
            failures.append(f"Missing managed file: {relative}")
    # These explicit overrides can suppress otherwise installed global context.
    if (home / ".codex/AGENTS.override.md").is_file() and (home / ".codex/AGENTS.override.md").stat().st_size:
        failures.append("Codex AGENTS.override.md takes precedence over managed AGENTS.md context")
    settings = home / ".claude/settings.json"
    try:
        if settings.is_file() and json.loads(settings.read_text()).get("disableAllHooks", False):
            failures.append("Claude disableAllHooks suppresses the managed RTK hook")
    except (ValueError, OSError):
        failures.append("Cannot validate Claude hook settings")
    for variable in ("CODEX_HOME", "CLAUDE_CONFIG_DIR", "KIRO_HOME"):
        if os.environ.get(variable):
            failures.append(f"{variable} is set; integration targets the standard home directories")
    print("RTK: Claude conservative automatic hook; Codex/Kiro instruction fallback")
    print("No external authentication or network checks performed.")
    for issue in failures:
        print(f"ATTENTION: {issue}")
    return bool(failures)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("check", "apply", "doctor", "info"))
    parser.add_argument("--home", type=Path, default=Path.home())
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    try:
        if args.action == "info":
            data = information(args.home, args.bundle)
            if args.json:
                print(json.dumps(data, indent=2))
            else:
                facts = data["host"]
                print(f'{facts["host"]}: {facts["role"]} ({facts["platform"]})')
                print(f'Context: {data["context"]}; workspace: ' + (data["workspace"]["root"] if data["workspace"] else "none"))
                if data["workspace"]:
                    workspace = data["workspace"]
                    print(f'HANDOFF: {workspace["handoff"]}; age={workspace["handoff_age_seconds"]}s; conflicts={len(workspace["handoff_conflicts"])}')
                    for repo in workspace["repositories"]:
                        print(f'{repo["name"]}: branch={repo["branch"] or "detached"}; dirty={repo["dirty"]}; worktrees={repo["worktree_count"]}')
                print("Orca: " + data["orca_runtime_status"])
                print("Sandbox: " + json.dumps(data["sandbox"]))
                for warning in data["warnings"]:
                    print("ATTENTION: " + warning)
            return 0
        if args.action == "doctor":
            return doctor(args.home, args.bundle)
        manifest = json.loads((args.bundle / "manifest.json").read_text())
        reconcile(args.home, manifest, args.action == "check")
        return 0
    except (ValueError, OSError, subprocess.TimeoutExpired) as exc:
        # Error type/path only; never include a raw settings file or parser document.
        print(f"ai-environment: {type(exc).__name__}: integration validation failed; recovery was attempted for any written fleet entries.", file=__import__("sys").stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
