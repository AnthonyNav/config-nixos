#!/usr/bin/env python3
"""Prepare bounded, locally owned Syncthing ignores before any folder registration."""
import argparse
import json
import os
from pathlib import Path
import tempfile


def read(path):
    if path.is_symlink() or (path.exists() and not path.is_file()):
        raise ValueError("Ignore/ownership paths must be regular local files")
    return path.read_text() if path.exists() else None


def block(name, body):
    return f"# BEGIN fleet-ignore-{name}\n{body}# END fleet-ignore-{name}\n"


def remove_owned(raw, previous):
    for name in ("deny", "scope"):
        start, end = f"# BEGIN fleet-ignore-{name}", f"# END fleet-ignore-{name}"
        if raw.count(start) != raw.count(end) or raw.count(start) > 1:
            raise ValueError("Malformed managed ignore markers")
        if start in raw:
            expected = block(name, previous.get(name, ""))
            if not previous or expected not in raw:
                raise ValueError("Managed ignore rules were edited locally")
            raw = raw.replace(expected, "", 1)
        elif name in previous:
            raise ValueError("Managed ignore rules were removed locally")
    for line in raw.splitlines():
        stripped = line.strip()
        # Existing positive user exclusions are kept. Reinclusions/includes
        # need explicit migration because they could override the mandatory scope.
        if stripped.startswith("#include") or (stripped and not stripped.startswith("#") and "!" in stripped.split("/")[0]):
            raise ValueError("User ignore reinclusions/includes require manual migration")
    return raw


def plan(folders):
    changes = []
    for folder in folders:
        if "ignorePatterns" not in folder:
            continue
        root = Path(folder["path"])
        if root.is_symlink() or any(parent.is_symlink() for parent in root.parents):
            raise ValueError("Workspace folder must not traverse a symlink")
        patterns = folder["ignorePatterns"]
        if not isinstance(patterns, list) or any(not isinstance(p, str) or "\n" in p or p.startswith(("!", "#")) for p in patterns):
            raise ValueError("Invalid mandatory ignore patterns")
        target = root / ".stignore"
        state = root / ".stignore.fleet-state"
        raw = read(target) or ""
        previous = json.loads(read(state) or "{}")
        if not isinstance(previous, dict):
            raise ValueError("Invalid ignore ownership")
        user = remove_owned(raw, previous)
        desired = {"deny": "\n".join(patterns) + "\n", "scope": "!/shared\n!/shared/**\n*\n"}
        content = block("deny", desired["deny"]) + user + ("\n" if user and not user.endswith("\n") else "") + block("scope", desired["scope"])
        if not previous and target.exists():
            backup = root / ".stignore.fleet-backup"
            if backup.exists() or backup.is_symlink():
                raise ValueError("Existing ignore backup requires manual reconciliation")
            changes.append((backup, None, raw))
        for path, updated in ((target, content), (state, json.dumps(desired, indent=2) + "\n")):
            old = read(path)
            if old != updated:
                changes.append((path, old, updated))
    return changes


def atomic_write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=".fleet-ignore-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(content)
        os.chmod(name, 0o600)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def prepare(folders, check=False):
    changes = plan(folders)  # Validate every workspace before writing any file.
    if check:
        return
    written = []
    try:
        for path, before, after in changes:
            if read(path) != before:
                raise ValueError("Ignore configuration changed during reconciliation")
            atomic_write(path, after)
            written.append((path, before, after))
    except (ValueError, OSError):
        for path, before, after in reversed(written):
            if read(path) == after:
                if before is None:
                    path.unlink()
                else:
                    atomic_write(path, before)
        raise


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    try:
        prepare(json.loads(os.environ["SYNCTHING_FLEET_FOLDERS_JSON"]), args.check)
    except (ValueError, OSError):
        print("Syncthing ignore preflight failed; reconcile local ignore ownership before registering folders.", file=__import__("sys").stderr)
        raise SystemExit(78)
