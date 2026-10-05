#!/usr/bin/env python3
"""Explicit refresh of Orca-owned mutable stubs; never an activation action."""
import argparse
import os
from pathlib import Path
import subprocess
import sys

CORE = ("orca-cli", "orchestration", "computer-use")


def commands(binary, home, android=False, dry_run=False):
    names = [*CORE, *(["orca-emulator-android"] if android else [])]
    installed, missing = [], []
    for name in names:
        path = home / ".agents/skills" / name
        if path.is_symlink() or (path / "SKILL.md").is_symlink():
            raise ValueError("Orca-owned skills must be mutable local placements")
        (installed if (path / "SKILL.md").is_file() else missing).append(name)
    result = []
    for action, selected in (("install", missing), ("update", installed)):
        if not selected:
            continue
        command = [binary, "skills", action]
        for name in selected:
            command += ["--skill", name]
        if action == "install":
            command += ["--agent", "universal"]
        if dry_run:
            command += ["--dry-run", "--json"]
        result.append(command)
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--android", action="store_true", help="Explicitly include Android automation stubs")
    args = parser.parse_args()
    try:
        for command in commands(args.binary, Path.home(), args.android, args.dry_run):
            result = subprocess.run(command, env=os.environ.copy(), check=False)
            if result.returncode:
                raise SystemExit(result.returncode)
    except (ValueError, OSError):
        print("orca-skills-sync: local skill placement validation failed; keep fleet skills under Home Manager and mutable Orca skills outside store links.", file=sys.stderr)
        raise SystemExit(77)
