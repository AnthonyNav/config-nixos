#!/usr/bin/env python3
"""Real Git recovery and CLI boundaries in temporary homes; no external accounts."""
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


identity = load("workspace-context")
portable = load("workspace")
hook = load("ai-workspace-hook")
opencode = load("ai-opencode")
manager = load("ai-environment")


class WorkspaceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name) / "host-a"
        self.home.mkdir()
        self.git_binary = shutil.which("git")
        self.config = self.policy(self.home)
        self.config_path = self.home / "policy.json"
        self.config_path.write_text(json.dumps(self.config))
        self.env = {k: v for k, v in os.environ.items() if not k.startswith(("GIT_", "FLEET_", "AWS_", "GH_", "GITHUB_", "OPENCODE_"))}
        self.env.update(HOME=str(self.home), GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1",
                        PYTHONDONTWRITEBYTECODE="1", GIT_ALLOW_PROTOCOL="file")

    def policy(self, home):
        return {"homeDirectory": str(home), "binaries": {"git": self.git_binary, "ssh": shutil.which("ssh"), "gh": "/unused", "aws": "/unused"},
                "policy": {"identities": {name: {"roots": [f"Workspace/{name}/"], "aws": {"profile": name + "-readonly"},
                                                 "git": {"name": name, "email": name + "@example.org"},
                                                 "github": {"alias": "github.com-" + name}, "sshKey": ".ssh/id_" + name}
                                          for name in ("work", "personal")}}}

    def cli(self, *arguments, cwd=None, expected=0, env=None, policy=None):
        result = subprocess.run([sys.executable, "-B", str(SCRIPTS / "workspace-context.py"), "--config",
                                 str(policy or self.config_path), "workspace", *arguments],
                                cwd=cwd or self.home, env=env or self.env, capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, expected, result.stderr)
        return result

    def raw(self, *arguments, cwd=None):
        result = subprocess.run([self.git_binary, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.org", *arguments],
                                cwd=cwd or self.home, env=self.env, capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def source(self, name="backend"):
        path = Path(self.tmp.name) / (name + ".git")
        self.raw("init", "-b", "main", str(path))
        (path / "README.md").write_text("fixture\n")
        (path / ".envrc").write_text("touch BOOTSTRAP_MUST_NOT_RUN\n")
        self.raw("-C", str(path), "add", ".")
        self.raw("-C", str(path), "commit", "-m", "Initial fixture")
        return path

    def create(self, context="work", name="cello"):
        self.cli("new", context, name)
        return self.home / "Workspace" / context / name

    def test_idempotent_creation_preserves_notes_and_legacy_data(self):
        legacy = self.home / "Workspace/work/shared"
        legacy.mkdir(parents=True)
        (legacy / "keep.txt").write_text("keep")
        root = self.create()
        handoff = root / "HANDOFF.md"
        handoff.write_text(handoff.read_text() + "\nMy decisions\n")
        before = handoff.read_bytes()
        self.create()
        self.assertEqual(before, handoff.read_bytes())
        self.assertEqual((legacy / "keep.txt").read_text(), "keep")
        self.assertTrue(all((root / name).is_dir() for name in ("docs", "assets", "repos")))

    def test_multiple_repos_registration_identity_and_status(self):
        root = self.create()
        for name in ("backend", "frontend"):
            source = self.source(name)
            self.cli("repo", "add", "cello", str(source), "--context", "work")
            self.cli("repo", "add", "cello", str(source), "--context", "work")
            self.assertFalse((root / "BOOTSTRAP_MUST_NOT_RUN").exists())
            self.assertEqual((root / "HANDOFF.md").read_text().count(f"| {name} |"), 1)
        result = json.loads(self.cli("status", "cello", "--context", "work", "--json").stdout)
        repos = result["workspaces"][0]["repositories"]
        self.assertEqual([repo["name"] for repo in repos], ["backend", "frontend"])
        self.assertTrue(all(repo["branch"] == "main" and not repo["dirty"] for repo in repos))
        self.assertTrue(all(repo["project_environment_declared"] for repo in repos))
        # Never copy a remote URL or handoff body into safe diagnostics.
        self.assertNotIn(str(Path(self.tmp.name) / "backend.git"), json.dumps(result))

    def test_ambiguity_and_invalid_names(self):
        self.create()
        self.create("personal")
        self.cli("status", "cello", expected=64)
        data = json.loads(self.cli("status", "cello", "--context", "personal", "--json").stdout)
        self.assertEqual(data["workspaces"][0]["context"], "personal")
        current = self.home / "Workspace/work/cello"
        selected = json.loads(self.cli("status", "--context", "personal", "--json", cwd=current).stdout)
        self.assertTrue(all(workspace["context"] == "personal" for workspace in selected["workspaces"]))
        for name in ("../escape", "repos", "shared", ".hidden", "-option"):
            self.cli("new", "work", name, expected=64 if not name.startswith("-") else 2)

    def test_symlink_and_credential_urls_are_rejected_before_clone(self):
        root = self.create()
        outside = self.home / "outside"
        outside.mkdir()
        (root / "repos").rmdir()
        (root / "repos").symlink_to(outside)
        self.cli("repo", "add", "cello", str(self.source()), "--context", "work", expected=64)
        self.assertEqual(list(outside.iterdir()), [])
        before = (root / "HANDOFF.md").read_text()
        for source in ("https://user:private-fixture@example.org/repo.git", "https://example.org/repo.git?token=private-fixture", "ext::touch private-fixture"):
            output = self.cli("repo", "add", "cello", source, "--context", "work", expected=64)
            self.assertNotIn("private-fixture", output.stdout + output.stderr)
        self.assertEqual(before, (root / "HANDOFF.md").read_text())

    def test_conflicts_and_registry_errors_preserve_files(self):
        root = self.create()
        source = self.source()
        conflict = root / "HANDOFF.sync-conflict-fixture.md"
        conflict.write_text("competing decisions")
        self.cli("repo", "add", "cello", str(source), "--context", "work", expected=64)
        self.assertFalse((root / "repos/backend").exists())
        conflict.unlink()
        path = root / "HANDOFF.md"
        path.write_text("User-owned custom handoff\n")
        self.cli("repo", "add", "cello", str(source), "--context", "work", expected=64)
        self.assertEqual(path.read_text(), "User-owned custom handoff\n")
        self.assertFalse((root / "repos/backend").exists())

    def test_external_worktree_and_other_workspace_conflict(self):
        root = self.create()
        self.cli("repo", "add", "cello", str(self.source()), "--context", "work")
        external = self.home / "external"
        self.raw("-C", str(root / "repos/backend"), "worktree", "add", "-b", "task/external", str(external))
        output = subprocess.run([sys.executable, "-B", str(SCRIPTS / "workspace-context.py"), "--config", str(self.config_path),
                                 "workspace-context", "status"], cwd=external, env=self.env, capture_output=True, text=True)
        self.assertEqual(output.returncode, 0, output.stderr)
        self.assertEqual(json.loads(output.stdout)["workspace"]["root"], str(root))
        self.assertIn("# cello", hook.context(self.config, external))
        listed = portable.repositories(self.config, root)[0]["worktrees"]
        self.assertTrue(any(tree["path"] == str(external) and tree["branch"] == "task/external" for tree in listed))
        other = self.create(name="other")
        self.raw("-C", str(root / "repos/backend"), "worktree", "add", "-b", "task/conflict", str(other / "repos/conflicting"))
        self.cli("status", cwd=other / "repos/conflicting", expected=64)

    def test_resume_on_second_host_and_wip_cleanup(self):
        root = self.create()
        source = self.source()
        self.cli("repo", "add", "cello", str(source), "--context", "work")
        repo = root / "repos/backend"
        self.raw("-C", str(repo), "switch", "-c", "task/resume")
        (repo / "work.txt").write_text("portable progress")
        self.raw("-C", str(repo), "add", "work.txt")
        self.raw("-C", str(repo), "commit", "-m", "WIP: preserve progress")
        self.assertEqual(portable.repositories(self.config, root)[0]["wip_commits"], 1)
        self.raw("-C", str(repo), "push", "origin", "task/resume")
        sha = self.raw("-C", str(repo), "rev-parse", "HEAD")
        handoff = root / "HANDOFF.md"
        handoff.write_text(handoff.read_text().replace("| main | main |", "| main | task/resume |") +
                           f"\nLast published task/resume: {sha}\n")
        second = Path(self.tmp.name) / "host-b"
        second.mkdir()
        config = self.policy(second)
        policy = second / "policy.json"
        policy.write_text(json.dumps(config))
        recovered = portable.create(config, "work", "cello")
        (recovered / "HANDOFF.md").write_text(handoff.read_text())
        self.cli("repo", "add", "cello", str(source), "--context", "work", cwd=second, policy=policy)
        target = recovered / "repos/backend"
        self.raw("-C", str(target), "switch", "--track", "origin/task/resume")
        self.assertEqual(self.raw("-C", str(target), "rev-parse", "HEAD"), sha)
        self.assertEqual((target / "work.txt").read_text(), "portable progress")
        self.assertIn("task/resume", (recovered / "HANDOFF.md").read_text())
        self.raw("-C", str(target), "commit", "--amend", "-m", "Implement portable progress")
        self.assertNotIn("WIP:", self.raw("-C", str(target), "log", "main..HEAD", "--format=%s"))
        self.assertTrue(portable.repositories(config, recovered)[0]["review_history_ready"])

    def test_orca_open_uses_supported_cli_without_pinning_app_identity(self):
        root = self.create()
        self.cli("repo", "add", "cello", str(self.source()), "--context", "work")
        bin_dir = self.home / "bin"
        bin_dir.mkdir()
        capture = self.home / "orca-calls.jsonl"
        fake = bin_dir / "orca-ide"
        fake.write_text(f'#!{sys.executable}\nimport json,os,sys\nwith open(os.environ["TEST_CALLS"],"a") as f: f.write(json.dumps({{"args":sys.argv[1:],"context":os.environ.get("FLEET_CONTEXT_OVERRIDE"),"gh":os.environ.get("GH_CONFIG_DIR")}})+"\\n")\n')
        fake.chmod(0o700)
        self.cli("open", "cello", "--context", "work", env=self.env | {"PATH": str(bin_dir), "TEST_CALLS": str(capture), "FLEET_CONTEXT_OVERRIDE": "personal", "GH_CONFIG_DIR": "/wrong"})
        calls = [json.loads(line) for line in capture.read_text().splitlines()]
        self.assertEqual(calls[0]["args"], ["open", "--json"])
        self.assertEqual(calls[1]["args"], ["repo", "add", "--path", str(root / "repos/backend"), "--json"])
        self.assertTrue(all(call["context"] is None and call["gh"] is None for call in calls))
        self.cli("open", "cello", "--context", "work", env=self.env | {"PATH": str(self.home / "empty")})

    def test_native_context_adapters_and_safe_fleet_info(self):
        root = self.create()
        self.cli("repo", "add", "cello", str(self.source()), "--context", "work")
        bundle = self.home / "bundle"
        (bundle / "skills/fleet-workspace").mkdir(parents=True)
        (bundle / "skills/fleet-workspace/SKILL.md").write_text("fixture")
        (bundle / "host.json").write_text(json.dumps({"host": "fixture", "role": "workstation", "platform": "x86_64-linux"}))
        (bundle / "workspace-policy.json").write_text(json.dumps(self.config))
        (bundle / "registry.json").write_text("[]")
        (bundle / "opencode-overlay.json").write_text('{"instructions":["fleet.md"],"mcp":{}}')
        value = opencode.overlay(bundle, self.config, self.env, [str(root / "repos/backend")])
        self.assertIn(str(root / "HANDOFF.md"), json.loads(value["OPENCODE_CONFIG_CONTENT"])["instructions"])
        self.assertIn("# cello", hook.context(self.config, root / "repos/backend"))
        before = Path.cwd()
        try:
            os.chdir(root / "repos/backend")
            data = manager.information(self.home, bundle)
        finally:
            os.chdir(before)
        self.assertEqual(data["workspace"]["root"], str(root))
        self.assertNotIn(str(Path(self.tmp.name) / "backend.git"), json.dumps(data))
        self.assertFalse(data["sandbox"]["codex"]["runtime_verified"])
        (root / "HANDOFF.md").write_text("x" * 32769)
        self.assertNotIn("x" * 100, hook.context(self.config, root))


if __name__ == "__main__":
    unittest.main()
