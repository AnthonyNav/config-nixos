#!/usr/bin/env python3
"""Validate the public catalogue and contextual dispatch without a desktop."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(sys.argv.pop(1)).resolve()
spec = importlib.util.spec_from_file_location("catalog", ROOT / "scripts/fleet-catalog.py")
catalog = importlib.util.module_from_spec(spec)
spec.loader.exec_module(catalog)


class Contract(unittest.TestCase):
    def test_generated_guide(self):
        data = catalog.load(ROOT / "dotfiles/fleet/actions.json")
        self.assertEqual(catalog.guide(data), (ROOT / "docs/fleet-shortcuts.md").read_text())
        self.assertEqual(next(e["args"] for e in data["menu"] if e["key"] == "T"), ["terminal"])
        self.assertEqual(next(e["args"] for e in data["menu"] if e["key"] == "A"), ["files"])

    def test_menu_fits_normal_terminal(self):
        data = catalog.load(ROOT / "dotfiles/fleet/actions.json")
        layout = catalog.menu_layout(data["menu"], 24, 80)
        self.assertEqual(len(layout), len(data["menu"]))
        self.assertTrue(all(row < 23 and column < 80 for row, column, _ in layout))
        self.assertTrue(any(line.startswith("    K") for _, _, line in layout))

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.directory = Path(self.tmp.name)
        self.log = self.directory / "log"
        # Real jq parses fake compositor responses; no real IPC is contacted.
        hyprctl = self.directory / "hyprctl"
        hyprctl.write_text('#!/usr/bin/env python3\nimport os,sys\nif sys.argv[1:]==["-j","activewindow"]: print(os.environ["WINDOW"])\nelse:\n with open(os.environ["LOG"],"a") as f: f.write(repr(sys.argv[1:])+"\\n")\n')
        hyprctl.chmod(0o700)
        self.env = dict(os.environ, PATH=str(self.directory) + ":" + os.environ["PATH"], LOG=str(self.log))

    def tearDown(self):
        self.tmp.cleanup()

    def edit(self, app, action):
        self.env["WINDOW"] = json.dumps({"class": app, "address": "0x123"})
        return subprocess.run(["bash", str(ROOT / "scripts/fleet-ui-linux.sh"), "edit", action], env=self.env, capture_output=True, text=True)

    def test_terminal_undo_is_not_sent(self):
        self.assertNotEqual(self.edit("kitty", "undo").returncode, 0)
        self.assertFalse(self.log.exists())

    def test_unknown_app_is_not_sent(self):
        self.assertNotEqual(self.edit("unknown", "copy").returncode, 0)
        self.assertFalse(self.log.exists())

    def test_unknown_app_keeps_menu_hotkey(self):
        self.env["WINDOW"] = json.dumps({"class": "unknown", "address": "0x123"})
        result = subprocess.run(["bash", str(ROOT / "scripts/fleet-ui-linux.sh"), "menu-hotkey"], env=self.env, capture_output=True)
        self.assertEqual(result.returncode, 0)
        self.assertIn("SUPER ALT,Return,address:0x123", self.log.read_text())

    def test_terminal_copy(self):
        self.assertEqual(self.edit("kitty", "copy").returncode, 0)
        self.assertIn("CTRL SHIFT,c,address:0x123", self.log.read_text())

    def test_browser_undo(self):
        self.assertEqual(self.edit("firefox", "undo").returncode, 0)
        self.assertIn("CTRL,z,address:0x123", self.log.read_text())

    def test_code_uses_own_context_bindings(self):
        self.assertEqual(self.edit("Code", "paste").returncode, 0)
        self.assertIn("SUPER,v,address:0x123", self.log.read_text())

    def test_quit_uses_graceful_app_shortcut(self):
        self.assertEqual(self.edit("kitty", "quit").returncode, 0)
        log = self.log.read_text()
        self.assertIn("CTRL SHIFT,q,address:0x123", log)
        self.assertNotIn("kill", log)


unittest.main()
