#!/usr/bin/env python3
"""Merge public Linux Code shortcuts while preserving user-owned entries."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import sys
import tempfile


def load_jsonc(path):
    spec = importlib.util.spec_from_file_location("fleet_jsonc", path)
    parser = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(parser)
    return parser.jsonc


def read(path):
    if path.is_symlink() or (path.exists() and not path.is_file()):
        raise ValueError("Expected a mutable regular file")
    return path.read_text() if path.exists() else ""


def safe_path(home, path):
    if not path.is_absolute() or not path.is_relative_to(home) or ".." in path.parts:
        raise ValueError("Integration paths must stay below the declared home")
    for ancestor in (path, *path.parents):
        if ancestor.is_symlink():
            raise ValueError("Refusing a symlinked integration path")
        if ancestor == home:
            break


def validate(entries):
    if not isinstance(entries, list) or not all(
        isinstance(entry, dict)
        and isinstance(entry.get("key"), str)
        and entry["key"].strip()
        and isinstance(entry.get("command"), str)
        and entry["command"].strip()
        and isinstance(entry.get("when", ""), str)
        for entry in entries
    ):
        raise ValueError("Expected a Code keybinding array")
    return entries


def key(entry):
    # VSCode accepts meta, win and cmd as the same modifier on Linux.
    chords = []
    for chord in entry["key"].lower().split():
        modifiers = set()
        while match := re.match(r"^(ctrl|shift|alt|meta|win|cmd)[+-]", chord):
            modifier = match.group(1)
            modifiers.add("meta" if modifier in ("win", "cmd") else modifier)
            chord = chord[match.end():]
        if chord == "[enter]":
            chord = "enter"
        chords.append("+".join([*sorted(modifiers), chord]))
    return " ".join(chords)


def identity(entry):
    return key(entry), entry.get("when", "").strip()


def menu_available(home, target, jsonc):
    """An explicit Code binding keeps the desktop chord in the application."""
    safe_path(home, target)
    raw = read(target)
    current = validate(jsonc('{"bindings":\n' + raw + '\n}')["bindings"]) if raw.strip() else []
    return not any(key(entry).split(" ")[0] in ("alt+meta+enter", "alt+meta+return") for entry in current)


def merge(current, previous, desired):
    remaining = list(current)
    for entry in previous:
        if entry in remaining:
            remaining.remove(entry)  # Remove exactly one recorded entry.
        elif any(identity(value) == identity(entry) for value in remaining):
            raise ValueError("A fleet-owned binding was modified locally")
    owned = []
    for entry in desired:
        # An identical binding already supplied by the user stays user-owned.
        if entry in remaining:
            continue
        if any(key(value) == key(entry) and value not in desired for value in remaining):
            # Different conditions may overlap; do not silently shadow them.
            raise ValueError("A user binding conflicts with a fleet shortcut")
        remaining.append(entry)
        owned.append(entry)
    return remaining, owned


def atomic_write(path, content, mode=0o600):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=".fleet-bindings-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(content)
        os.chmod(name, mode)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def reconcile(home, target, state, desired, jsonc, check=False):
    for path in (target, state, state.parent / "backups"):
        safe_path(home, path)
    desired = validate(desired)
    if len({identity(entry) for entry in desired}) != len(desired):
        raise ValueError("Duplicate fleet keybinding")
    raw, state_raw = read(target), read(state)
    current = validate(jsonc('{"bindings":\n' + raw + '\n}')["bindings"]) if raw.strip() else []
    previous = json.loads(state_raw) if state_raw else {}
    relative = str(target.relative_to(home))
    if not isinstance(previous, dict) or (previous and (previous.get("schema_version") != 1 or previous.get("target") != relative or "entries" not in previous)):
        raise ValueError("Invalid ownership manifest")
    previous_entries = validate(previous.get("entries", []))
    merged, owned = merge(current, previous_entries, desired)
    updated = json.dumps(merged, indent=2, ensure_ascii=False) + "\n"
    recorded = {"schema_version": 1, "target": relative, "entries": owned}
    manifest = json.dumps(recorded, indent=2, ensure_ascii=False) + "\n"
    changed = current != merged or (not target.exists() and bool(merged))
    if check:
        return changed
    if read(target) != raw or read(state) != state_raw:
        raise ValueError("Configuration changed during reconciliation")
    existed = target.exists()
    mode = target.stat().st_mode & 0o777 if existed else 0o600
    written = False
    try:
        if changed:
            if existed:
                backups = state.parent / "backups"
                backups.mkdir(mode=0o700, parents=True, exist_ok=True)
                fd, name = tempfile.mkstemp(prefix="keybindings-", suffix=".jsonc", dir=backups)
                with os.fdopen(fd, "w") as stream:
                    stream.write(raw)
                os.chmod(name, 0o600)
            atomic_write(target, updated, mode)
            written = True
        if previous != recorded:
            atomic_write(state, manifest)
    except (ValueError, OSError):
        # Preserve a concurrent editor change; otherwise roll back a failed
        # ownership write so the next activation cannot misidentify bindings.
        if written and read(target) == updated:
            if existed:
                atomic_write(target, raw, mode)
            else:
                target.unlink()
        raise
    return changed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--home", type=Path, required=True)
    parser.add_argument("--target", type=Path, required=True)
    parser.add_argument("--state", type=Path, required=True)
    parser.add_argument("--bindings", type=Path, required=True)
    parser.add_argument("--jsonc-parser", type=Path, required=True)
    parser.add_argument("action", choices=("check", "apply", "menu-available"))
    args = parser.parse_args()
    try:
        if args.action == "menu-available":
            available = menu_available(args.home, args.target, load_jsonc(args.jsonc_parser))
            print("true" if available else "false")
            return 0 if available else 1
        reconcile(args.home, args.target, args.state, json.loads(args.bindings.read_text()),
                  load_jsonc(args.jsonc_parser), args.action == "check")
    except (ValueError, OSError, TypeError, AttributeError):
        print("fleet-editor-bindings: validation failed; resolve malformed files, symlinks or shortcut conflicts before activation. User bindings were preserved.", file=sys.stderr)
        return 77
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
