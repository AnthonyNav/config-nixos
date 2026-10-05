#!/usr/bin/env python3
"""Credential and config boundaries using isolated processes, homes and fake servers."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPTS = Path(sys.argv.pop(1)).resolve()


def load(name):
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), SCRIPTS / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


opencode = load("ai-opencode")
skills = load("orca-skills-sync")


class RuntimeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.work = self.home / "Workspace/work"
        self.personal = self.home / "Workspace/personal"
        for path in (self.work, self.personal):
            path.mkdir(parents=True)
        self.capture = self.home / "capture.json"
        self.fake = self.home / "fake"
        self.fake.write_text(f'#!{sys.executable}\nimport json, os, sys\nfrom pathlib import Path\nPath(os.environ["TEST_CAPTURE"]).write_text(json.dumps({{"args":sys.argv[1:], "env":{{k:v for k,v in os.environ.items() if k.startswith(("FLEET_MCP_", "API_ACCESS_", "TEST_TOKEN", "OPENCODE_"))}}}}))\n')
        self.fake.chmod(0o700)
        self.policy = {
            "homeDirectory": str(self.home), "binaries": {"git": shutil.which("git")},
            "policy": {"identities": {name: {"roots": [f"Workspace/{name}/"], "aws": {"profile": f"{name}-readonly"}} for name in ("work", "personal")}},
        }
        self.policy_path = self.home / "policy.json"
        self.policy_path.write_text(json.dumps(self.policy))
        self.entry = {"id": "example", "context": "work", "authentication": "runtime-env", "requiredSecrets": ["TEST_TOKEN"], "transport": "stdio", "command": str(self.fake), "args": ["mcp"]}
        self.env = os.environ.copy()
        for name in list(self.env):
            if name.startswith(("FLEET_", "GIT_", "OPENCODE_")):
                self.env.pop(name)
        self.env.update(HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / ".config"),
                        XDG_CACHE_HOME=str(self.home / ".cache"), XDG_DATA_HOME=str(self.home / ".local/share"),
                        XDG_STATE_HOME=str(self.home / ".local/state"), TEST_CAPTURE=str(self.capture),
                        GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1", PYTHONDONTWRITEBYTECODE="1")

    def mcp(self, entry=None, cwd=None, extra=None, expected=0):
        path = self.home / "entry.json"
        path.write_text(json.dumps(entry or self.entry))
        result = subprocess.run([sys.executable, "-B", str(SCRIPTS / "mcp-context.py"), "--policy", str(self.policy_path), "--entry", str(path), "--proxy", str(self.fake)],
                                cwd=cwd or self.work, env=self.env | (extra or {}), capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, expected, result.stderr)
        return result

    def test_wrong_context_is_rejected_before_server_or_credential_use(self):
        extra = {"FLEET_MCP_WORK_EXAMPLE_TEST_TOKEN": "work-fixture"}
        for cwd in (self.home, self.personal):
            self.mcp(cwd=cwd, extra=extra, expected=77)
            self.assertFalse(self.capture.exists())

    def test_runtime_env_uses_only_the_context_prefixed_secret(self):
        self.mcp(extra={"FLEET_MCP_WORK_EXAMPLE_TEST_TOKEN": "work-fixture", "FLEET_MCP_PERSONAL_EXAMPLE_TEST_TOKEN": "personal-fixture", "TEST_TOKEN": "wrong-unprefixed"})
        data = json.loads(self.capture.read_text())
        self.assertEqual(data["env"], {"TEST_TOKEN": "work-fixture"})
        self.assertEqual(data["args"], ["mcp"])
        self.mcp(extra={"TEST_TOKEN": "wrong-unprefixed"}, expected=77)

    def test_private_file_contract_symlinks_permissions_and_redacted_errors(self):
        entry = self.entry | {"authentication": "runtime-file"}
        path = self.home / ".config/fleet/secrets/work/mcp/example.json"
        path.parent.mkdir(parents=True)
        path.write_text('{"TEST_TOKEN":"private-fixture"}')
        path.chmod(0o600)
        self.mcp(entry)
        self.assertEqual(json.loads(self.capture.read_text())["env"], {"TEST_TOKEN": "private-fixture"})
        path.chmod(0o644)
        self.mcp(entry, expected=77)
        path.chmod(0o600)
        path.write_text('broken private-fixture')
        result = self.mcp(entry, expected=77)
        self.assertNotIn("private-fixture", result.stderr)
        path.unlink()
        path.symlink_to(self.policy_path)
        self.mcp(entry, expected=77)

    def test_http_bridge_sends_token_via_environment_and_never_opens_a_server(self):
        entry = self.entry | {"transport": "http", "url": "https://example.org/mcp", "requiredSecrets": ["API_ACCESS_TOKEN"]}
        self.mcp(entry, extra={"FLEET_MCP_WORK_EXAMPLE_API_ACCESS_TOKEN": "http-fixture"})
        data = json.loads(self.capture.read_text())
        self.assertEqual(data["env"], {"API_ACCESS_TOKEN": "http-fixture"})
        self.assertEqual(data["args"], ["--transport", "streamablehttp", "--log-level", "ERROR", "https://example.org/mcp"])

    def test_jsonc_parser_handles_comments_strings_and_trailing_commas(self):
        self.assertEqual(opencode.jsonc('/* comment */ {"url": "https://example.org/a,}", // line\n "array": ["a",],}'), {"url": "https://example.org/a,}", "array": ["a"]})
        for raw in ('{"bad":', '{/* unfinished', '[]'):
            with self.assertRaises(ValueError):
                opencode.jsonc(raw)

    def bundle(self):
        bundle = self.home / "bundle"
        bundle.mkdir()
        entry = {"type": "local", "command": ["/nix/store/fixture/bin/mcp"], "enabled": True}
        (bundle / "opencode-overlay.json").write_text(json.dumps({"instructions": ["/nix/store/context.md"], "mcp": {"fleet-example": entry}}))
        (bundle / "registry.json").write_text(json.dumps([self.entry]))
        return bundle

    def test_opencode_preserves_user_jsonc_and_concurrent_contexts(self):
        bundle = self.bundle()
        path = self.home / ".config/opencode/opencode.jsonc"
        path.parent.mkdir(parents=True)
        raw = '// Personal settings\n{"provider":{"custom":{"name":"Mine"}},"instructions":["personal.md"],"permission":{"bash":"ask"},}\n'
        path.write_text(raw)
        inline = '{"model":"custom/model","mcp":{"mine":{"type":"remote","url":"https://example.org"}},"permission":{"edit":"ask"}}'
        environments = []
        for cwd in (self.work, self.personal):
            result = subprocess.run([sys.executable, "-B", str(SCRIPTS / "ai-opencode.py"), "--bundle", str(bundle), "--policy", str(self.policy_path), "--binary", str(self.fake), "run", "literal $(value); argument"], cwd=cwd,
                                    env=self.env | {"OPENCODE_CONFIG_CONTENT": inline}, capture_output=True, text=True, timeout=15)
            self.assertEqual(result.returncode, 0, result.stderr)
            data = json.loads(self.capture.read_text())
            environments.append(json.loads(data["env"]["OPENCODE_CONFIG_CONTENT"]))
            self.assertEqual(data["args"], ["run", "literal $(value); argument"])
            self.assertEqual(path.read_text(), raw)
        for value in environments:
            self.assertEqual(value["model"], "custom/model")
            self.assertEqual(value["permission"], {"edit": "ask"})
            self.assertIn("mine", value["mcp"])
            self.assertEqual(value["instructions"], ["personal.md", "/nix/store/context.md"])
        self.assertTrue(environments[0]["mcp"]["fleet-example"]["enabled"])
        self.assertFalse(environments[1]["mcp"]["fleet-example"]["enabled"])

    def test_opencode_conflicts_and_malformed_jsonc_do_not_launch_or_write(self):
        bundle = self.bundle()
        path = self.home / ".config/opencode/opencode.jsonc"
        path.parent.mkdir(parents=True)
        for raw in ('{broken', '{"mcp":{"fleet-example":{"type":"remote","url":"https://other.example.org"}}}'):
            path.write_text(raw)
            with self.assertRaises(ValueError):
                opencode.overlay(bundle, self.policy, self.env)
            self.assertEqual(path.read_text(), raw)
        self.assertFalse(self.capture.exists())

    def test_opencode_resolves_project_argument_and_run_directory(self):
        bundle = self.bundle()
        for arguments in ([str(self.work)], ["--model", "custom/model", str(self.work)], ["run", "--dir", str(self.work), "message"], ["run", "--dir=" + str(self.work), "message"]):
            value = json.loads(opencode.overlay(bundle, self.policy, self.env, arguments)["OPENCODE_CONFIG_CONTENT"])
            self.assertTrue(value["mcp"]["fleet-example"]["enabled"])
        value = json.loads(opencode.overlay(bundle, self.policy, self.env, [str(self.personal)])["OPENCODE_CONFIG_CONTENT"])
        self.assertFalse(value["mcp"]["fleet-example"]["enabled"])

    def test_orca_refresh_is_explicit_bounded_and_rejects_store_links(self):
        path = self.home / ".agents/skills/orca-cli"
        path.mkdir(parents=True)
        (path / "SKILL.md").write_text("mutable stub")
        commands = skills.commands("/nix/store/orca/bin/orca-ide", self.home, dry_run=True)
        self.assertTrue(all("--dry-run" in command and "--json" in command for command in commands))
        self.assertEqual(len(commands), 2)
        self.assertNotIn("orca-emulator-android", str(commands))
        self.assertNotIn("--all", str(commands))
        self.assertIn("orca-emulator-android", str(skills.commands("orca-ide", self.home, android=True)))
        (path / "SKILL.md").unlink()
        (path / "SKILL.md").symlink_to(self.policy_path)
        with self.assertRaises(ValueError):
            skills.commands("orca-ide", self.home)


if __name__ == "__main__":
    unittest.main()
