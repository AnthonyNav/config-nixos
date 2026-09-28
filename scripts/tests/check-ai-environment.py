#!/usr/bin/env python3
"""Behavioral tests using isolated homes; no network or real agent state."""
import copy
import contextlib
import io
import importlib.util
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import tomllib
import unittest
from unittest.mock import patch


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


manager = load("manager", sys.argv[1])
hook = load("hook", sys.argv[2])
bundle = Path(sys.argv[3])
rtk = sys.argv[4]
sys.argv = sys.argv[:1]


class Integration(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.manifest = json.loads((bundle / "manifest.json").read_text())

    def seed(self, rel, text):
        path = self.home / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path

    def test_preserve_settings_update_disable_and_dry_run(self):
        settings = self.seed(".claude/settings.json", json.dumps({
            "permissions": {"deny": ["Bash(rm *)"]},
            "env": {"PRIVATE_TEST_VALUE": "fixture-only"},
            "hooks": {"PreToolUse": [{"matcher": "Edit", "hooks": []}]},
        }))
        context = self.seed(".codex/AGENTS.md", "Personal instructions\n")
        original = settings.read_text()
        manager.reconcile(self.home, self.manifest, True)
        self.assertEqual(settings.read_text(), original)
        self.assertFalse((self.home / ".local/state/nixos-ai/ownership.json").exists())
        manager.reconcile(self.home, self.manifest, False)
        first = settings.read_text(), context.read_text()
        manager.reconcile(self.home, self.manifest, False)
        self.assertEqual(first, (settings.read_text(), context.read_text()))
        value = json.loads(settings.read_text())
        self.assertEqual(value["permissions"], {"deny": ["Bash(rm *)"]})
        self.assertEqual(len(value["hooks"]["PreToolUse"]), 2)
        self.assertTrue(context.read_text().startswith("Personal instructions\n"))
        self.assertEqual(settings.stat().st_mode & 0o777, 0o600)
        next_manifest = copy.deepcopy(self.manifest)
        next_manifest["text"][".codex/AGENTS.md"] += "\nUpdated host fact\n"
        manager.reconcile(self.home, next_manifest, False)
        self.assertEqual(context.read_text().count(manager.START), 1)
        self.assertIn("Updated host fact", context.read_text())
        manager.reconcile(self.home, {"json": {}, "text": {}}, False)
        self.assertEqual(json.loads(settings.read_text()), json.loads(original))
        self.assertEqual(context.read_text().strip(), "Personal instructions")
        self.assertEqual(settings.with_name("settings.json.fleet-ai-backup").stat().st_mode & 0o777, 0o600)

    def test_malformed_json_does_not_write_any_target(self):
        self.seed(".claude/settings.json", "{broken")
        context = self.seed(".codex/AGENTS.md", "Keep this\n")
        with self.assertRaises(ValueError):
            manager.reconcile(self.home, self.manifest, False)
        self.assertEqual(context.read_text(), "Keep this\n")
        self.assertFalse((self.home / ".local/state/nixos-ai/ownership.json").exists())

    def test_modified_owned_context_is_not_overwritten(self):
        manager.reconcile(self.home, self.manifest, False)
        context = self.home / ".codex/AGENTS.md"
        context.write_text(context.read_text().replace("NixOS", "LOCAL EDIT"))
        with self.assertRaises(ValueError):
            manager.reconcile(self.home, self.manifest, False)
        self.assertIn("LOCAL EDIT", context.read_text())

    def test_symlinks_are_not_followed(self):
        outside = self.seed("outside", "Keep this")
        (self.home / ".claude").mkdir()
        (self.home / ".claude/settings.json").symlink_to(outside)
        with self.assertRaises(ValueError):
            manager.reconcile(self.home, self.manifest, False)
        self.assertEqual(outside.read_text(), "Keep this")

    def test_mcp_collision_removal_and_toml_preservation(self):
        entry = {"path": ["mcpServers", "fleet-example"], "kind": "set", "value": {"url": "https://example.org/mcp"}}
        raw = json.dumps({"mcpServers": {"personal": {"command": "local-server"}}})
        updated = manager.merge_json(raw, [], [entry])
        self.assertEqual(json.loads(manager.merge_json(updated, [entry], [])), json.loads(raw))
        conflict = json.dumps({"mcpServers": {"fleet-example": {"url": "https://other.example/mcp"}}})
        with self.assertRaises(ValueError):
            manager.merge_json(conflict, [], [entry])
        text = '# Personal comment\nmodel = "personal-model"\n'
        owned = '[mcp_servers."fleet-example"]\nurl = "https://example.org/mcp"\n'
        updated = manager.merge_text(text, None, owned, True)
        self.assertEqual(tomllib.loads(updated)["model"], "personal-model")
        self.assertIn("# Personal comment", updated)
        restored = manager.merge_text(updated, owned, None, True)
        self.assertEqual(tomllib.loads(restored), tomllib.loads(text))
        with self.assertRaises(ValueError):
            manager.merge_text(owned, None, owned, True)

    def test_optional_stdio_enable_disable_preserves_normal_workflow(self):
        personal = {"mcpServers": {"personal": {"command": "user-tool", "args": []}}}
        self.seed(".claude.json", json.dumps(personal))
        self.seed(".kiro/settings/mcp.json", json.dumps(personal))
        self.seed(".codex/config.toml", 'model = "personal-model"\n')
        manager.reconcile(self.home, self.manifest, False)
        normal = {str(p.relative_to(self.home)): p.read_text() for p in self.home.rglob('*') if p.is_file() and not p.name.endswith('fleet-ai-backup')}
        optional = copy.deepcopy(self.manifest)
        command = "/nix/store/fixture-fleet-artemis/bin/fleet-artemis"
        for name in (".claude.json", ".kiro/settings/mcp.json"):
            optional["json"][name] = [{"path": ["mcpServers", "fleet-artemis"], "kind": "set", "value": {"command": command, "args": ["mcp"]}}]
        optional["text"][".codex/config.toml"] = '[mcp_servers."fleet-artemis"]\ncommand = "' + command + '"\nargs = ["mcp"]\n'
        manager.reconcile(self.home, optional, False)
        manager.reconcile(self.home, self.manifest, False)
        for name in (".claude.json", ".kiro/settings/mcp.json"):
            self.assertEqual(json.loads((self.home / name).read_text()), personal)
        self.assertEqual(tomllib.loads((self.home / ".codex/config.toml").read_text()), {"model": "personal-model"})
        self.assertEqual((self.home / ".claude/settings.json").read_text(), normal[".claude/settings.json"])
        self.assertEqual((self.home / ".codex/AGENTS.md").read_text(), normal[".codex/AGENTS.md"])

    def test_doctor_detects_missing_integration_without_connecting(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertTrue(manager.doctor(self.home, bundle))

    def test_doctor_healthy_then_detects_disabled_hook(self):
        manager.reconcile(self.home, self.manifest, False)
        for relative in json.loads((bundle / "files.json").read_text()):
            self.seed(relative, "fixture")
        with patch.object(manager.shutil, "which", return_value="/fixture/bin/tool"), patch.dict(os.environ, {}, clear=True):
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertFalse(manager.doctor(self.home, bundle))
            settings = self.home / ".claude/settings.json"
            value = json.loads(settings.read_text())
            value["disableAllHooks"] = True
            settings.write_text(json.dumps(value))
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertTrue(manager.doctor(self.home, bundle))

    def test_hook_upgrade_removes_old_group(self):
        manager.reconcile(self.home, self.manifest, False)
        replacement = copy.deepcopy(self.manifest)
        group = replacement["json"][".claude/settings.json"][0]["value"][0]
        group["hooks"][0]["command"] = "/new/store/hook"
        manager.reconcile(self.home, replacement, False)
        settings = json.loads((self.home / ".claude/settings.json").read_text())
        self.assertEqual(settings["hooks"]["PreToolUse"], [group])

    def test_malformed_markers_and_backup_symlinks_fail_before_writes(self):
        self.seed(".codex/AGENTS.md", manager.START + "\npartial edit")
        with self.assertRaises(ValueError):
            manager.reconcile(self.home, self.manifest, False)
        self.assertFalse((self.home / ".claude/settings.json").exists())
        (self.home / ".codex/AGENTS.md").unlink()
        outside = self.seed("outside", "Preserve this")
        path = self.seed(".claude/settings.json", "{}")
        path.with_name("settings.json.fleet-ai-backup").symlink_to(outside)
        with self.assertRaises(ValueError):
            manager.reconcile(self.home, self.manifest, False)
        self.assertEqual(outside.read_text(), "Preserve this")


class Hook(unittest.TestCase):
    def test_supported_rewrite_preserves_input_and_permissions(self):
        for command in ("git status", "git diff"):
            value = hook.rewrite({"tool_name": "Bash", "tool_input": {"command": command, "timeout": 1000}}, rtk)
            output = value["hookSpecificOutput"]
            self.assertEqual(output["updatedInput"], {"command": shlex.quote(rtk) + " " + command, "timeout": 1000})
            self.assertNotIn("permissionDecision", output)

    def test_unsupported_and_composed_commands_pass_through(self):
        for command in ("git diff --name-only", "git push", "git status && touch sentinel",
                        "git status\ntouch sentinel", "git status > output", "echo $(touch sentinel)",
                        "rtk git status", "nix build", ""):
            self.assertIsNone(hook.rewrite({"tool_name": "Bash", "tool_input": {"command": command}}, rtk))
        self.assertIsNone(hook.rewrite({"tool_name": "Read", "tool_input": {"command": "git status"}}, rtk))

    def test_rtk_failure_does_not_execute_original(self):
        with tempfile.TemporaryDirectory() as tmp:
            fake = Path(tmp) / "rtk"
            fake.write_text("#!/bin/sh\nexit 1\n")
            fake.chmod(0o700)
            self.assertIsNone(hook.rewrite({"tool_name": "Bash", "tool_input": {"command": "git status"}}, str(fake)))


if __name__ == "__main__":
    unittest.main()
