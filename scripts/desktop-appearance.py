#!/usr/bin/env python3
"""Merge native shell settings and apply explicit, reversible appearance presets."""
import argparse
import copy
import fcntl
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import sys

THEME_FILES = ("kitty-colors.conf", "rofi.rasi", "hyprland-colors.conf", "starship.toml")


def check_path(path):
    for component in (path, *path.parents):
        if component.is_symlink():
            raise ValueError(f"Refusing symlink destination: {component}")
    if path.exists() and not path.is_file():
        raise ValueError(f"Expected a regular file: {path}")


def atomic_write(path, raw):
    check_path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".appearance-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as output:
            output.write(raw)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def encode(value):
    return (json.dumps(value, indent=2, ensure_ascii=False) + "\n").encode()


def read_object(path):
    check_path(path)
    value = json.loads(path.read_text()) if path.exists() else {}
    if not isinstance(value, dict):
        raise ValueError(f"Expected JSON object: {path}")
    return value


def merge(target, source, missing_only=False):
    result = copy.deepcopy(target)
    for key, value in source.items():
        if isinstance(value, dict):
            current = result.get(key, {})
            if not isinstance(current, dict):
                raise ValueError(f"Expected object at shell setting: {key}")
            result[key] = merge(current, value, missing_only)
        elif not missing_only or key not in result:
            result[key] = copy.deepcopy(value)
    return result


def merge_actions(shell, policy):
    launcher = shell.setdefault("launcher", {})
    actions = launcher.setdefault("actions", copy.deepcopy(policy["nativeActions"]))
    if not isinstance(actions, list) or any(not isinstance(action, dict) for action in actions):
        raise ValueError("launcher.actions must be a list of objects")
    names = {action.get("name") for action in actions}
    for action in policy["actions"]:
        if action["name"] not in names:
            actions.append(copy.deepcopy(action))
            names.add(action["name"])


def render(template, colours):
    def replace(match):
        value = colours.get(match[1])
        if not isinstance(value, str) or not re.fullmatch(r"[0-9a-fA-F]{6}", value):
            raise ValueError(f"Invalid or missing colour: {match[1]}")
        return value
    result = re.sub(r"\{\{\s*(\w+)\.hex\s*\}\}", replace, template)
    if "{{" in result:
        raise ValueError("Unresolved theme template")
    return result.encode()


def update_files(changes):
    # Validate every destination and backup before the first write.
    snapshots = {}
    for path in changes:
        check_path(path)
        check_path(path.with_name(path.name + ".appearance-backup"))
        snapshots[path] = path.read_bytes() if path.exists() else None
    written = []
    try:
        for path, raw in changes.items():
            previous = snapshots[path]
            if previous == raw:
                continue
            if previous is not None:
                atomic_write(path.with_name(path.name + ".appearance-backup"), previous)
            atomic_write(path, raw)
            written.append(path)
    except Exception:
        restore_files({path: snapshots[path] for path in written})
        raise
    return snapshots


def restore_files(snapshots):
    for path, raw in snapshots.items():
        if raw is None:
            path.unlink(missing_ok=True)
        else:
            atomic_write(path, raw)


def run(args, policy):
    home = Path.home()
    config = Path(os.environ.get("XDG_CONFIG_HOME", home / ".config"))
    state = Path(os.environ.get("XDG_STATE_HOME", home / ".local/state")) / "caelestia"
    shell_path = config / "caelestia/shell.json"
    preset_path = state / "desktop-preset.json"
    hypr_path = state / "theme/hyprland-preset.conf"
    scheme_path = state / "scheme.json"
    shell = read_object(shell_path)
    saved = read_object(preset_path)
    scheme = read_object(scheme_path)
    if args.command == "list":
        print("\n".join(policy["presets"]))
        return
    if args.command == "status":
        print(json.dumps({"preset": saved.get("preset", "personalizado"), "mode": scheme.get("mode", "dark")}, ensure_ascii=False))
        return
    if args.command == "bootstrap":
        shell = merge(shell, policy["defaults"], missing_only=True)
        merge_actions(shell, policy)
        colours = scheme.get("colours", policy["colours"]["dark"])
        changes = {shell_path: encode(shell)}
        if not scheme:
            changes[scheme_path] = encode({"name": "catppuccin", "flavour": "mocha", "mode": "dark", "variant": "tonalspot", "colours": colours})
        if not hypr_path.exists():
            changes[hypr_path] = policy["presets"]["diario"]["hyprland"].encode()
        opacity = "1.0" if scheme.get("mode") == "light" or saved.get("preset") == "enfoque" else "0.94"
        changes[state / "theme/kitty-opacity.conf"] = f"background_opacity {opacity}\n".encode()
        for name in THEME_FILES:
            template = (config / "caelestia/templates" / name).read_text()
            changes[state / "theme" / name] = render(template, colours)
        update_files(changes)
        return
    preset = policy["presets"].get(args.preset)
    if preset is None:
        raise ValueError(f"Unknown preset: {args.preset}; use diario, claro or enfoque")
    shell = merge(shell, preset["shell"])
    changes = {shell_path: encode(shell), hypr_path: preset["hyprland"].encode(), preset_path: encode({"preset": args.preset})}
    # Keep previous theme outputs too: a failing theme command must not leave
    # a partially selected preset or erase unrelated Nexus preferences.
    theme_snapshots = {}
    for name in THEME_FILES:
        path = state / "theme" / name
        check_path(path)
        theme_snapshots[path] = path.read_bytes() if path.exists() else None
    opacity_path = state / "theme/kitty-opacity.conf"
    check_path(opacity_path)
    theme_snapshots[opacity_path] = opacity_path.read_bytes() if opacity_path.exists() else None
    if scheme:
        theme_snapshots[scheme_path] = scheme_path.read_bytes()
    else:
        theme_snapshots[scheme_path] = None
    snapshots = update_files(changes)
    try:
        subprocess.run(["caelestia", "scheme", "set", "--name", "catppuccin", "--flavour", "latte" if preset["mode"] == "light" else "mocha", "--mode", preset["mode"]], check=True, timeout=90)
        active = read_object(scheme_path)
        if active.get("mode") != preset["mode"]:
            raise ValueError("The CLI did not apply the requested mode")
        for name in THEME_FILES:
            expected = render((config / "caelestia/templates" / name).read_text(), policy["colours"][preset["mode"]])
            if (state / "theme" / name).read_bytes() != expected:
                raise ValueError(f"Theme output was not updated: {name}")
    except Exception:
        restore_files(snapshots | theme_snapshots)
        raise
    if os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
        env = os.environ.copy()
        env.pop("LD_LIBRARY_PATH", None)
        try:
            subprocess.run(["hyprctl", "reload"], env=env, check=True, timeout=10)
        except (OSError, subprocess.SubprocessError) as error:
            print(f"Perfil guardado; no se pudo recargar Hyprland: {error}", file=sys.stderr)
    print(f"Perfil aplicado: {args.preset}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--policy", type=Path, required=True)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("bootstrap", "list", "status"):
        commands.add_parser(name)
    commands.add_parser("apply").add_argument("preset")
    args = parser.parse_args()
    policy = json.loads(args.policy.read_text())
    if args.command in ("list", "status"):
        run(args, policy)
        return
    state = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "caelestia"
    lock_path = state / "appearance.lock"
    check_path(lock_path)
    state.mkdir(parents=True, exist_ok=True)
    with lock_path.open("a") as lock:
        os.chmod(lock_path, 0o600)
        fcntl.flock(lock, fcntl.LOCK_EX)
        run(args, policy)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print(f"desktop-preset: {error}", file=sys.stderr)
        sys.exit(1)
