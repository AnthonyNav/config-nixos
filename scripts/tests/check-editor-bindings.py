#!/usr/bin/env python3
"""Exercise mutable editor reconciliation with isolated fixture homes."""
import copy
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location("editor_bindings", sys.argv[1])
manager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(manager)
parser = manager.load_jsonc(sys.argv[2])
catalog = manager.validate(json.loads(Path(sys.argv[3]).read_text()))
sys.argv = sys.argv[:1]


class Bindings(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.home = Path(temp.name).resolve()
        self.target = self.home / ".config/Code/User/keybindings.json"
        self.state = self.home / ".local/state/fleet/editor-bindings/ownership.json"

    def seed(self, raw):
        self.target.parent.mkdir(parents=True, exist_ok=True)
        self.target.write_text(raw)

    def apply(self, desired=catalog, check=False):
        return manager.reconcile(self.home, self.target, self.state, desired, parser, check)

    def test_preserve_jsonc_backup_idempotence_update_and_remove(self):
        user = {"key": "ctrl+k ctrl+u", "command": "custom.fixture", "args": {"url": "https://fixture.invalid/*kept*/"}}
        raw = '// Personal bindings\n[\n' + json.dumps(user) + ', /* trailing comma */\n]\n'
        self.seed(raw)
        self.assertTrue(self.apply(check=True))
        self.assertEqual(self.target.read_text(), raw)
        self.assertFalse(self.state.exists())
        self.apply()
        result = json.loads(self.target.read_text())
        self.assertEqual(result[0], user)
        self.assertEqual(result[1:], catalog)
        backups = list((self.state.parent / "backups").iterdir())
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), raw)
        self.assertEqual(backups[0].stat().st_mode & 0o777, 0o600)
        first = self.target.read_text(), self.state.read_text(), self.target.stat().st_mtime_ns
        self.assertFalse(self.apply())
        self.assertEqual(first, (self.target.read_text(), self.state.read_text(), self.target.stat().st_mtime_ns))
        self.assertEqual(list((self.state.parent / "backups").iterdir()), backups)
        next_catalog = copy.deepcopy(catalog)
        next_catalog[0]["command"] = "updated.fixture"
        self.apply(next_catalog)
        self.assertEqual(json.loads(self.target.read_text())[0], user)
        self.apply([])
        self.assertEqual(json.loads(self.target.read_text()), [user])

    def test_identical_preexisting_bindings_stay_user_owned(self):
        self.seed(json.dumps([catalog[0]]))
        self.apply()
        owned = json.loads(self.state.read_text())["entries"]
        self.assertNotIn(catalog[0], owned)
        self.apply([])
        self.assertEqual(json.loads(self.target.read_text()), [catalog[0]])

    def test_user_shortcut_conflicts_preserve_bytes_and_state(self):
        for condition in (catalog[0]["when"], "editorTextFocus"):
            user = {"key": "win+c", "command": "custom.copy", "when": condition}
            raw = json.dumps([user])
            self.seed(raw)
            with self.assertRaises(ValueError):
                self.apply()
            self.assertEqual(self.target.read_text(), raw)
            self.assertFalse(self.state.exists())

    def test_modified_owned_binding_is_preserved(self):
        self.apply()
        entries = json.loads(self.target.read_text())
        entries[0]["command"] = "locally.modified"
        raw = json.dumps(entries)
        self.target.write_text(raw)
        before = self.state.read_text()
        with self.assertRaises(ValueError):
            self.apply()
        self.assertEqual(self.target.read_text(), raw)
        self.assertEqual(self.state.read_text(), before)

    def test_malformed_arrays_and_ownership_do_not_write(self):
        for raw in ('[broken', '{}', '[{"key":"meta+c"}]', '[/*unterminated'):
            self.seed(raw)
            with self.assertRaises(ValueError):
                self.apply()
            self.assertEqual(self.target.read_text(), raw)
            self.assertFalse(self.state.exists())
        self.seed('[]')
        self.state.parent.mkdir(parents=True)
        self.state.write_text('{"schema_version":1,"target":"wrong","entries":[]}')
        with self.assertRaises(ValueError):
            self.apply()
        self.assertEqual(self.target.read_text(), '[]')

    def test_symlinked_files_directories_and_outside_paths_are_rejected(self):
        outside = self.home / "outside.json"
        outside.write_text('[]')
        self.target.parent.mkdir(parents=True)
        self.target.symlink_to(outside)
        with self.assertRaises(ValueError):
            self.apply()
        self.target.unlink()
        self.target.parent.rmdir()
        self.target.parent.symlink_to(self.home)
        with self.assertRaises(ValueError):
            self.apply()
        self.assertEqual(outside.read_text(), '[]')
        with self.assertRaises(ValueError):
            manager.safe_path(self.home, self.home / '..' / 'external.json')

    def test_ownership_write_failure_rolls_back_target(self):
        self.seed('[] // keep original formatting\n')
        raw = self.target.read_text()
        write = manager.atomic_write

        def fail_state(path, content, mode=0o600):
            if path == self.state:
                raise OSError("fixture disk failure")
            return write(path, content, mode)

        with patch.object(manager, "atomic_write", side_effect=fail_state):
            with self.assertRaises(OSError):
                self.apply()
        self.assertEqual(self.target.read_text(), raw)
        self.assertFalse(self.state.exists())

    def test_terminal_ctrl_signals_and_desktop_chords_are_not_bound(self):
        self.assertTrue(all(entry["key"].startswith("meta+") for entry in catalog))
        self.assertTrue(all("alt" not in entry["key"] for entry in catalog))
        for entry in catalog:
            if entry["command"] in ("undo", "redo"):
                self.assertIn("!terminalFocus", entry["when"])
        self.assertIn({"key": "meta+c", "command": "workbench.action.terminal.copySelection", "when": "terminalFocus && terminalHasSelection"}, catalog)
        self.assertFalse(any(entry["key"] in ("ctrl+c", "ctrl+z") for entry in catalog))

    def test_custom_code_menu_chord_is_preserved_and_detected(self):
        self.assertTrue(manager.menu_available(self.home, self.target, parser))
        for chord in ("meta+alt+enter", "ALT+WIN+enter", "meta-alt-enter", "win+alt+[Enter]", "cmd+alt+enter ctrl+z"):
            user = {"key": chord, "command": "custom.menu", "when": "editorTextFocus"}
            self.seed(json.dumps([user]))
            self.assertFalse(manager.menu_available(self.home, self.target, parser))
            self.apply()
            self.assertIn(user, json.loads(self.target.read_text()))
            self.apply([])
            self.assertEqual(json.loads(self.target.read_text()), [user])

    def test_editor_line_navigation_and_panel_are_scoped(self):
        for entry in catalog:
            if entry["command"].startswith("cursor"):
                self.assertEqual(entry["when"], "editorTextFocus && !terminalFocus")
        self.assertIn({"key": "meta+j", "command": "workbench.action.togglePanel"}, catalog)
        self.assertIn({"key": "meta+q", "command": "workbench.action.quit"}, catalog)


unittest.main()
