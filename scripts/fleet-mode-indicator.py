#!/usr/bin/env python3
"""Unfocused Wayland mode indicator; private IPC never signals stored PIDs."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import stat
import sys


def directory():
    runtime = Path(os.environ["XDG_RUNTIME_DIR"])
    if runtime.is_symlink() or runtime.stat().st_uid != os.getuid():
        raise ValueError("unsafe runtime directory")
    path = runtime / "fleet-window-mode"
    path.mkdir(mode=0o700, exist_ok=True)
    info = path.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o700:
        raise ValueError("unsafe mode directory")
    return path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["start", "stop", "ready"])
    parser.add_argument("mode", choices=["move", "resize"], nargs="?")
    parser.add_argument("--pid", type=int)
    args = parser.parse_args()
    path = directory()
    if args.action == "stop":
        fd = os.open(path / "stop", os.O_WRONLY | os.O_CREAT | os.O_NOFOLLOW, 0o600)
        os.close(fd)
        return
    if args.action == "ready":
        try:
            ready = json.loads((path / "ready").read_text())
            sys.exit(0 if ready["pid"] == args.pid else 1)
        except (OSError, ValueError):
            sys.exit(1)
    if not args.mode:
        parser.error("start requires a mode")
    lock = os.open(path / "lock", os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    # The caller requests the previous indicator to stop before starting this
    # one. Waiting for its lock avoids a race while GTK processes the request.
    fcntl.flock(lock, fcntl.LOCK_EX)
    for name in ["stop", "ready"]:
        (path / name).unlink(missing_ok=True)
    import gi
    gi.require_version("Gtk", "3.0")
    gi.require_version("GtkLayerShell", "0.1")
    from gi.repository import GLib, Gtk, GtkLayerShell
    window = Gtk.Window()
    GtkLayerShell.init_for_window(window)
    GtkLayerShell.set_layer(window, GtkLayerShell.Layer.OVERLAY)
    GtkLayerShell.set_keyboard_mode(window, GtkLayerShell.KeyboardMode.NONE)
    GtkLayerShell.set_anchor(window, GtkLayerShell.Edge.TOP, True)
    GtkLayerShell.set_margin(window, GtkLayerShell.Edge.TOP, 16)
    window.set_accept_focus(False)
    hint = "Mover: flechas · 1–9/0: escritorio" if args.mode == "move" else "Redimensionar: flechas"
    label = Gtk.Label(label="Fleet · " + hint + " · Enter/Escape: salir")
    label.set_margin_start(20)
    label.set_margin_end(20)
    label.set_margin_top(12)
    label.set_margin_bottom(12)
    window.add(label)
    window.show_all()
    (path / "ready").write_text(json.dumps({"pid": os.getpid(), "mode": args.mode}))
    def poll():
        if (path / "stop").exists():
            Gtk.main_quit()
            return False
        return True
    GLib.timeout_add(100, poll)
    try:
        Gtk.main()
    finally:
        (path / "ready").unlink(missing_ok=True)
        (path / "stop").unlink(missing_ok=True)


if __name__ == "__main__":
    main()
