#!/usr/bin/env python3
"""Event-driven Hyprland layouts. Pure planning, one IPC writer, no polling."""
import argparse
import json
import logging
import math
import os
from pathlib import Path
import select
import socket
import subprocess
import time


def identity(monitor):
    return " ".join(monitor.get(key) or "Unknown" for key in ("make", "model", "serial"))


def logical_width(width, height, scale, transform):
    if scale <= 0 or width <= 0 or height <= 0:
        raise ValueError("Invalid monitor dimensions/scale")
    return math.ceil((height if transform in (1, 3, 5, 7) else width) / scale)


def supports(monitor, mode):
    width, rest = mode.split("x", 1)
    height, rate = rest.rstrip("Hz").split("@", 1)
    for available in monitor.get("availableModes", []):
        size, refresh = available.rstrip("Hz").split("@", 1)
        if size == f"{width}x{height}" and abs(float(refresh) - float(rate)) <= 0.06:
            return True
    return False


def plan(monitors, displays):
    active = [m for m in monitors if not m.get("disabled", False)]
    if not active:
        return "empty", []
    external = [m for m in active if not m["name"].startswith(("eDP-", "LVDS-"))]
    known = {role: [m for m in external if identity(m) == d["criteria"]]
             for role, d in displays.items()}
    matched = {role: values[0] for role, values in known.items() if len(values) == 1}
    known_group = (len(external) in (2, 3) and len(matched) == len(external)
                   and all(supports(m, displays[role]["mode"]) for role, m in matched.items()))
    rules = []
    if known_group:
        for role in ("center", "left", "right"):
            if role not in matched:
                continue
            display = displays[role]
            x, y = map(int, display["position"].split(","))
            # Two portrait panels without the center must remain contiguous.
            if "center" not in matched and role == "right":
                x = 0
            transform = {"normal": 0, "90": 1, "180": 2, "270": 3}[display["transform"]]
            rules.append(dict(name=matched[role]["name"], mode=display["mode"].rstrip("Hz"),
                              x=x, y=y, scale=display["scale"], transform=transform))
        internal = [m for m in active if m not in external]
        for m in internal:
            rules.append(current_rule(m, 0, 1920, 0))
        return "studio" if len(external) == 3 else "studio-pair", rules

    # Unknown desks (including a laptop + two external screens): preserve
    # resolution, refresh and scale, reset rotation, never guess physical sides.
    active.sort(key=lambda m: (not m["name"].startswith(("eDP-", "LVDS-")),
                               identity(m), m["name"]))
    x = 0
    for m in active:
        rules.append(current_rule(m, x, 0, 0))
        x += logical_width(m["width"], m["height"], m.get("scale", 1), 0)
    return f"portable-{len(active)}", rules


def current_rule(monitor, x, y, transform):
    scale = monitor.get("scale", 1)
    logical_width(monitor["width"], monitor["height"], scale, transform)
    return dict(name=monitor["name"],
                mode=f'{monitor["width"]}x{monitor["height"]}@{monitor["refreshRate"]}',
                x=x, y=y, scale=scale, transform=transform)


def command(rule):
    return f'{rule["name"]},{rule["mode"]},{rule["x"]}x{rule["y"]},{rule["scale"]},transform,{rule["transform"]}'


def unchanged(monitors, rules):
    by_name = {m["name"]: m for m in monitors}
    for r in rules:
        m = by_name[r["name"]]
        size, rate = r["mode"].split("@")
        if (size != f'{m["width"]}x{m["height"]}'
                or abs(float(rate) - m["refreshRate"]) > 0.06
                or any(m[key] != r[key] for key in ("x", "y", "scale", "transform"))):
            return False
    return True


def hyprctl(*args):
    env = os.environ.copy()
    env.pop("LD_LIBRARY_PATH", None)
    return subprocess.run(["hyprctl", *args], env=env, check=True,
                          capture_output=True, text=True, timeout=10).stdout


def reconcile(displays, dry_run=False):
    monitors = json.loads(hyprctl("monitors", "all", "-j"))
    name, rules = plan(monitors, displays)
    if dry_run:
        print(json.dumps(dict(profile=name, rules=[command(r) for r in rules])))
    elif rules and not unchanged(monitors, rules):
        result = hyprctl("--batch", ";".join("keyword monitor " + command(r) for r in rules))
        if any(line.strip() != "ok" for line in result.splitlines() if line.strip()):
            raise RuntimeError(result)
        logging.info("Applied %s", name)


def watch(displays):
    instance = os.environ["HYPRLAND_INSTANCE_SIGNATURE"]
    path = Path(os.environ["XDG_RUNTIME_DIR"]) / "hypr" / instance / ".socket2.sock"
    with socket.socket(socket.AF_UNIX) as stream:
        stream.connect(str(path))
        reconcile(displays)
        buffer = b""
        deadline = None
        retries = 0
        while True:
            timeout = None if deadline is None else max(0, deadline - time.monotonic())
            readable, _, _ = select.select([stream], [], [], timeout)
            if readable:
                data = stream.recv(65536)
                if not data:
                    return
                buffer += data
                lines = buffer.split(b"\n")
                buffer = lines.pop()
                for line in lines:
                    event = line.split(b">>", 1)[0]
                    if event in (b"monitoradded", b"monitoraddedv2", b"monitorremoved",
                                 b"configreloaded"):
                        deadline = time.monotonic() + 0.4
                        retries = 0
            elif deadline is not None:
                try:
                    reconcile(displays)
                    deadline = None
                except (OSError, ValueError, KeyError, subprocess.SubprocessError, RuntimeError):
                    logging.exception("Layout failed; keeping the compositor's safe default")
                    retries += 1
                    deadline = time.monotonic() + 1 if retries < 3 else None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--policy", type=Path, required=True)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--watch", action="store_true")
    mode.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO)
    displays = json.loads(args.policy.read_text())
    if args.watch:
        watch(displays)
    else:
        reconcile(displays, args.dry_run)


if __name__ == "__main__":
    main()
