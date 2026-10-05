#!/usr/bin/env python3
"""Portable project folders. Git owns code; HANDOFF owns recovery context."""
import argparse
import contextlib
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
from urllib.parse import urlsplit

START = "<!-- BEGIN fleet-workspace-repos -->"
END = "<!-- END fleet-workspace-repos -->"
HEADER = "| Repo | Remote | Relative path | Base branch | Active branch | Last observed remote commit |\n| --- | --- | --- | --- | --- | --- |"
TEMPLATE = """# {name}

Context: {context}
Last update: {updated}
Handoff owner: assign one writer before concurrent work.

## Objective

Describe the intended outcome and current focus.

## Repositories

{start}
{header}
{end}

Keep this table current when branches or remotes change. A locally cached
remote commit is an observation, not proof that today's changes were pushed.
Use portable remote URLs without credentials and paths relative to this folder.

## Resume

1. Read this file, then each repository's instructions and current Git diff.
2. Clone missing repos into the relative paths above; fetch and verify the
   required branch/commit. Review .envrc before allowing direnv.
3. Record dependency order and the minimum build/test commands below.
4. Recover with a new agent after a host restart; running processes are not
   transferred by Git or Syncthing.

Bootstrap commands and repository ordering: fill in before switching hosts.

## Current state and decisions

Record validated results, decisions and remaining work here.

## WIP transfer

For each active repo, record branch, last published SHA and remaining local
changes. Publishing requires the task's authorization. Clean WIP commits before
requesting PR review; coordinate any rewrite of a shared branch.

## Pending

- Complete objective, bootstrap and branch information.
- Resolve any HANDOFF.sync-conflict files before updating this handoff.

Keep secrets, pairing URLs, credentials and full transcripts out of this file.
"""


def safe_name(value):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,63}", value) or value in {"repos", "worktrees", "shared"}:
        raise ValueError("Use a project/repo name of 1-64 letters, digits, dots, underscores or hyphens; legacy folder names are reserved")
    return value


def local_path(path, boundary):
    """Reject symlink traversal and paths outside the managed project."""
    path, boundary = Path(path), Path(boundary).resolve()
    if path.is_symlink() or any(parent.is_symlink() for parent in path.parents):
        raise ValueError("Managed workspace paths must not traverse symlinks")
    resolved = path.resolve()
    if resolved != boundary and boundary not in resolved.parents:
        raise ValueError("Path escapes the managed workspace")
    return resolved


def context_root(config, context):
    if context not in ("work", "personal"):
        raise ValueError("Select work or personal")
    home = Path(config["homeDirectory"]).resolve()
    return local_path(home / "Workspace" / context, home)


def select(config, name, context, identity):
    safe_name(name)
    if context:
        candidates = [context]
    else:
        current = identity.resolve(config)["context"]
        candidates = [current] if current != "neutral" else ["work", "personal"]
    found = []
    for candidate in candidates:
        parent = context_root(config, candidate)
        root = local_path(parent / name, parent)
        if root.is_dir() and (root / "HANDOFF.md").exists():
            local_path(root / "HANDOFF.md", root)
            found.append((candidate, root))
    if len(found) != 1:
        raise ValueError("Workspace missing or ambiguous; select --context work|personal")
    return found[0]


def conflicts(root):
    return sorted(path.name for path in root.glob("HANDOFF.sync-conflict*.md"))


@contextlib.contextmanager
def lock(root):
    local_path(root / ".fleet-workspace.lock", root)
    descriptor = os.open(root / ".fleet-workspace.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        fcntl.flock(descriptor, fcntl.LOCK_EX)
        if conflicts(root):
            raise ValueError("Resolve HANDOFF sync conflicts before modifying this workspace")
        yield
    finally:
        os.close(descriptor)


def git(config, root, *arguments, env=None, required=False):
    probe_env = dict(os.environ if env is None else env)
    for key in ("GIT_DIR", "GIT_WORK_TREE", "GIT_COMMON_DIR", "GIT_INDEX_FILE"):
        probe_env.pop(key, None)
    result = subprocess.run([config["binaries"]["git"], "-C", str(root),
                             "-c", "core.fsmonitor=false", "-c", "core.hooksPath=/dev/null", "-c", "log.showSignature=false", *arguments],
                            env=probe_env, capture_output=True, text=True, timeout=15)
    if required and result.returncode:
        raise ValueError("Git operation failed; inspect the repository locally")
    return result.stdout.strip() if result.returncode == 0 else None


def repositories(config, root):
    parent = local_path(root / "repos", root)
    result = []
    if not parent.exists():
        return result
    for path in sorted(parent.iterdir()):
        local_path(path, parent)
        if not path.is_dir() or not (path / ".git").exists():
            continue
        # Fixed read-only probes: never execute project hooks or fetch.
        branch = git(config, path, "symbolic-ref", "--quiet", "--short", "HEAD")
        base = git(config, path, "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD")
        subjects = git(config, path, "log", "--format=%s", f"{base}..HEAD") if base else None
        wip = sum(bool(re.match(r"(?i)^WIP(?::|\s)", subject)) for subject in (subjects or "").splitlines()) if base else None
        worktrees = []
        for record in (git(config, path, "worktree", "list", "--porcelain", "-z") or "").split("\x00\x00"):
            fields = dict(field.partition(" ")[::2] for field in record.split("\x00") if field)
            if "worktree" in fields:
                worktrees.append({"path": fields["worktree"], "commit": fields.get("HEAD"),
                                  "branch": fields.get("branch", "").removeprefix("refs/heads/") or None,
                                  "locked": "locked" in fields, "prunable": "prunable" in fields})
        result.append({"name": path.name, "path": str(path), "relative_path": str(path.relative_to(root)),
                       "branch": branch, "commit": git(config, path, "rev-parse", "HEAD"),
                       "tracking_commit": git(config, path, "rev-parse", "--verify", "@{upstream}"),
                       "base_branch": base, "wip_commits": wip,
                       "review_history_ready": wip == 0 if wip is not None else None,
                       "dirty": bool(git(config, path, "status", "--porcelain", required=True)),
                       "worktree_count": len(worktrees), "worktrees": worktrees,
                       "project_environment_declared": any((path / file).is_file() for file in (".envrc", "flake.nix", "shell.nix"))})
    return result


def snapshot(config, location):
    if not location:
        return None
    root = local_path(Path(location["root"]), Path(config["homeDirectory"]))
    handoff = local_path(root / "HANDOFF.md", root)
    stat = handoff.stat()
    return location | {"handoff_updated_at": stat.st_mtime,
                       "handoff_age_seconds": max(0, int(time.time() - stat.st_mtime)),
                       "handoff_conflicts": conflicts(root),
                       "repositories": repositories(config, root),
                       "orca_available": shutil.which("orca-ide") is not None}


def create(config, context, name):
    safe_name(name)
    parent = context_root(config, context)
    root = local_path(parent / name, parent)
    root.mkdir(parents=True, exist_ok=True)
    with lock(root):
        for child in ("docs", "assets", "repos"):
            local_path(root / child, root).mkdir(exist_ok=True)
        path = local_path(root / "HANDOFF.md", root)
        try:
            with path.open("x") as stream:
                stream.write(TEMPLATE.format(name=name, context=context, start=START, end=END, header=HEADER,
                                             updated=time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())))
            path.chmod(0o600)
        except FileExistsError:
            if not path.is_file():
                raise ValueError("HANDOFF must be a regular local file")
    return root


def remote_url(value):
    if any(char in value for char in ("\n", "\r", "|", "\x00")) or value.startswith("-"):
        raise ValueError("Invalid remote URL")
    parsed = urlsplit(value)
    if parsed.scheme:
        if parsed.scheme not in ("ssh", "https", "file") or parsed.password or parsed.query or parsed.fragment:
            raise ValueError("Use SSH/HTTPS or a local Git source without embedded credentials")
        if parsed.username and not (parsed.scheme == "ssh" and parsed.username == "git"):
            raise ValueError("Remote URL must not contain credentials")
    elif ":" in value and not re.fullmatch(r"(git@)?[A-Za-z0-9.-]+:[A-Za-z0-9_./-]+", value):
        raise ValueError("Unsupported Git remote syntax")
    return value


def register_handoff(root, name, remote, branch, base, observed):
    path = local_path(root / "HANDOFF.md", root)
    raw = path.read_text()
    if raw.count(START) != 1 or raw.count(END) != 1 or raw.index(START) >= raw.index(END):
        raise ValueError("Handoff registry markers missing or malformed; preserve it and reconcile manually")
    before, remaining = raw.split(START, 1)
    table, after = remaining.split(END, 1)
    if any(line.startswith(f"| {name} |") for line in table.splitlines()):
        return
    values = (name, remote, f"repos/{name}", base or "fill in", branch or "detached: fill in", observed or "not verified")
    if any(any(char in value for char in ("\n", "\r", "|")) for value in values):
        raise ValueError("Repository metadata cannot be represented safely in the handoff")
    content = before + START + table.rstrip() + "\n| " + " | ".join(values) + " |\n" + END + after
    descriptor, temporary = tempfile.mkstemp(prefix=".fleet-handoff-", dir=root)
    try:
        with os.fdopen(descriptor, "w") as stream:
            stream.write(content)
        os.chmod(temporary, 0o600)
        if path.read_text() != raw:
            raise ValueError("Handoff changed concurrently; retry after reconciling")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def add_repo(config, config_path, identity, context, root, source, name=None):
    source = remote_url(source)
    name = safe_name(name or source.rstrip("/").rsplit("/", 1)[-1].rsplit(":", 1)[-1].removesuffix(".git"))
    parent = local_path(root / "repos", root)
    target = local_path(parent / name, parent)
    env = identity.scoped_git_environment(config, config_path, context, identity.clean_environment(context, config))
    env["FLEET_CONTEXT_OVERRIDE"] = context
    with lock(root):
        parent.mkdir(exist_ok=True)
        # Preflight the handoff before cloning or registering anything.
        handoff = local_path(root / "HANDOFF.md", root).read_text()
        if handoff.count(START) != 1 or handoff.count(END) != 1 or handoff.index(START) >= handoff.index(END):
            raise ValueError("Reconcile handoff registry markers before adding repositories")
        if target.exists():
            if not (target / ".git").exists() or git(config, target, "remote", "get-url", "origin", env=env) != source:
                raise ValueError("Existing repository/path differs; nothing was overwritten")
        else:
            temporary = Path(tempfile.mkdtemp(prefix=".fleet-clone-", dir=parent))
            try:
                result = subprocess.run([config["binaries"]["git"], "clone", "--", source, str(temporary)],
                                        cwd=root, env=env, capture_output=True, text=True, timeout=300)
                if result.returncode:
                    raise ValueError("Clone failed; check the selected context's credentials and remote")
                os.rename(temporary, target)
            finally:
                if temporary.exists():
                    shutil.rmtree(temporary)
        base = git(config, target, "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD", env=env)
        register_handoff(root, name, source, git(config, target, "symbolic-ref", "--quiet", "--short", "HEAD", env=env),
                         base.removeprefix("origin/") if base else None,
                         git(config, target, "rev-parse", "--verify", "@{upstream}", env=env))
    return target


def open_workspace(config, config_path, identity, context, root):
    print(str(root), flush=True)
    binary = shutil.which("orca-ide")
    if not binary:
        print("Orca unavailable; use the workspace path above.")
        return 0
    # Orca is long-lived and may host both identities. Do not pin the whole app
    # to this invocation's identity; its per-repo Git/MCP/agent adapters resolve
    # the actual cwd/common directory. Explicit SDK scope remains per agent.
    env = identity.clean_environment("neutral", config)
    for variable in ("FLEET_CONTEXT_OVERRIDE", "FLEET_WORKSPACE_ROOT", "FLEET_HANDOFF"):
        env.pop(variable, None)
    # The pinned CLI imports one project per repository. The filesystem/handoff
    # provides the multi-repo group; no opaque Orca database is edited.
    commands = [[binary, "open", "--json"]]
    commands.extend([binary, "repo", "add", "--path", repo["path"], "--json"] for repo in repositories(config, root))
    if len(commands) == 1:
        print("Add repositories before importing projects into Orca.")
        return 0
    for command in commands:
        result = subprocess.run(command, cwd=root, env=env, capture_output=True, text=True, timeout=60)
        if result.returncode:
            print("Orca could not open/import this workspace; local files remain available.")
            return 1
    print("Repositories registered in Orca; select a project/worktree there.")
    return 0


def main(config, config_path, arguments, identity):
    parser = argparse.ArgumentParser(prog="workspace")
    sub = parser.add_subparsers(dest="action", required=True)
    new = sub.add_parser("new", help="Create a project and a handoff without cloning")
    new.add_argument("context", choices=("work", "personal"))
    new.add_argument("name")
    repo = sub.add_parser("repo")
    repo_sub = repo.add_subparsers(dest="repo_action", required=True)
    add = repo_sub.add_parser("add")
    add.add_argument("name")
    add.add_argument("source")
    add.add_argument("--repo-name")
    for command in (add, sub.add_parser("open"), sub.add_parser("status")):
        if command != add:
            command.add_argument("name", nargs="?" if command.prog.endswith("status") else None)
        command.add_argument("--context", choices=("work", "personal"))
    sub.choices["status"].add_argument("--json", action="store_true")
    args = parser.parse_args(arguments)
    if args.action == "new":
        print(create(config, args.context, args.name))
        return 0
    if args.action == "status" and not args.name:
        info = identity.resolve(config)
        locations = [info["workspace"]] if info["workspace"] and (not args.context or info["workspace"]["context"] == args.context) else []
        if not locations:
            for context in ("work", "personal"):
                parent = context_root(config, context)
                if args.context and args.context != context:
                    continue
                if parent.exists():
                    for path in sorted(parent.iterdir()):
                        location = identity.workspace_location(config, path)
                        if location:
                            locations.append(location)
    else:
        context, root = select(config, args.name, args.context, identity)
        if args.action == "repo":
            print(add_repo(config, config_path, identity, context, root, args.source, args.repo_name))
            return 0
        if args.action == "open":
            return open_workspace(config, config_path, identity, context, root)
        locations = [identity.workspace_location(config, root)]
    data = {"schema_version": 1, "workspaces": [snapshot(config, location) for location in locations]}
    if args.json:
        print(json.dumps(data, indent=2))
    else:
        for item in data["workspaces"]:
            print(f'{item["context"]}/{item["name"]}: {item["root"]}')
            print(f'  HANDOFF age: {item["handoff_age_seconds"]}s; conflicts: {len(item["handoff_conflicts"])}')
            for repository in item["repositories"]:
                print(f'  {repository["name"]}: {repository["branch"] or "detached"}; dirty={repository["dirty"]}; worktrees={repository["worktree_count"]}; WIP={repository["wip_commits"]}')
        if not data["workspaces"]:
            print("No workspace found. Use workspace new work|personal NAME.")
    return 0
