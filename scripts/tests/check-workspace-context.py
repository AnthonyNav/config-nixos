#!/usr/bin/env python3
"""Exercise real Git commits/worktrees and isolated credential-routing processes."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPT = str(Path(sys.argv.pop(1)).resolve())
GIT = shutil.which("git")


class WorkspaceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.work = self.home / "Workspace/work/repos/project"
        self.personal = self.home / "Workspace/personal/repos/project"
        self.neutral = self.home / "other"
        for path in (self.work, self.personal, self.neutral):
            path.mkdir(parents=True)
        self.capture = self.home / "capture.json"
        fake = self.home / "fake"
        fake.write_text(f'#!{sys.executable}\nimport json, os, sys\nfrom pathlib import Path\nPath(os.environ["TEST_CAPTURE"]).write_text(json.dumps({{"args": sys.argv[1:], "env": {{k: v for k, v in os.environ.items() if k.startswith(("AWS_", "GH_", "GITHUB_", "GIT_", "WORK_"))}}}}))\n')
        fake.chmod(0o700)
        self.config = self.home / "policy.json"
        self.config.write_text(json.dumps({
            "homeDirectory": str(self.home),
            "binaries": {"git": GIT, "gh": str(fake), "aws": str(fake), "ssh": str(fake)},
            "policy": {"default": "neutral", "identities": {
                "work": {"roots": ["Workspace/work/"], "git": {"name": "Work", "email": "work@example.org"}, "sshKey": ".ssh/work", "github": {"alias": "github.com-work", "compatibilityAliases": ["github.com-kigo"]}, "aws": {"profile": "work-readonly"}},
                "personal": {"roots": ["Workspace/personal/", "projects/", "nixos-config/"], "git": {"name": "Personal", "email": "personal@example.org"}, "sshKey": ".ssh/personal", "github": {"alias": "github.com-personal"}, "aws": {"profile": "personal-readonly"}},
            }},
        }))
        self.env = os.environ.copy()
        for key in list(self.env):
            if key.startswith(("GIT_", "AWS_", "GH_", "GITHUB_", "FLEET_")):
                self.env.pop(key)
        self.env.update(HOME=str(self.home), GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL="/dev/null", TEST_CAPTURE=str(self.capture))

    def raw(self, *args, cwd=None):
        result = subprocess.run([GIT, *args], cwd=cwd or self.neutral, env=self.env, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def run_tool(self, action, *args, cwd=None, extra=None, expected=0):
        result = subprocess.run([sys.executable, SCRIPT, "--config", str(self.config), action, *args],
                                cwd=cwd or self.neutral, env=self.env | (extra or {}), capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, expected, result.stderr)
        return result

    def init(self, path):
        self.raw("-C", str(path), "init", "-q")

    def test_neutral_refuses_commits_and_auth_even_with_stale_shell_values(self):
        self.init(self.neutral)
        stale = {"WORK_CONTEXT": "work", "AWS_PROFILE": "work-readonly", "GH_TOKEN": "fixture-token", "GIT_AUTHOR_EMAIL": "work@example.org", "GIT_COMMITTER_EMAIL": "work@example.org"}
        self.run_tool("git", "commit", "--allow-empty", "-m", "neutral", extra=stale, expected=128)
        self.run_tool("gh", "api", "user", extra=stale, expected=77)
        self.run_tool("aws", "sts", "get-caller-identity", extra=stale, expected=77)
        self.assertFalse(self.capture.exists())

    def test_commit_identity_for_both_contexts_without_shell_hooks(self):
        for path, email in ((self.work, "work@example.org"), (self.personal, "personal@example.org")):
            self.init(path)
            self.run_tool("git", "-C", str(path), "commit", "--allow-empty", "-m", "context",
                          extra={"WORK_CONTEXT": "neutral", "GIT_AUTHOR_EMAIL": "wrong@example.org", "GIT_COMMITTER_EMAIL": "wrong@example.org"})
            self.assertEqual(self.raw("-C", str(path), "log", "-1", "--format=%ae:%ce"), f"{email}:{email}")

    def test_external_linked_worktree_inherits_original_context(self):
        self.init(self.work)
        self.run_tool("git", "commit", "--allow-empty", "-m", "initial", cwd=self.work)
        outside = self.home / "orca-worktree"
        self.raw("-C", str(self.work), "worktree", "add", "-q", "-b", "agent", str(outside))
        info = json.loads(self.run_tool("workspace-context", "status", cwd=outside).stdout)
        self.assertEqual(info["context"], "work")
        self.assertEqual(info["source"], "git-common-dir")
        self.run_tool("git", "commit", "--allow-empty", "-m", "agent", cwd=outside)
        self.assertEqual(self.raw("-C", str(outside), "log", "-1", "--format=%ae"), "work@example.org")

    def test_multiple_relative_C_and_explicit_work_tree(self):
        self.init(self.work)
        self.run_tool("git", "-C", "../Workspace", "-C", "work/repos/project", "commit", "--allow-empty", "-m", "nested")
        self.run_tool("git", "--git-dir", str(self.work / ".git"), "--work-tree", str(self.work), "commit", "--allow-empty", "-m", "target")
        self.assertEqual(self.raw("-C", str(self.work), "log", "-1", "--format=%ae"), "work@example.org")

    def test_explicit_git_directory_is_authoritative_for_repository_selection(self):
        self.init(self.personal)
        self.run_tool("git", "--git-dir=" + str(self.personal / ".git"), "commit", "--allow-empty", "-m", "target", cwd=self.work)
        self.assertEqual(self.raw("-C", str(self.personal), "log", "-1", "--format=%ae"), "personal@example.org")
        self.run_tool("git", "commit", "--allow-empty", "-m", "environment target", cwd=self.work, extra={"GIT_DIR": str(self.personal / ".git"), "GIT_WORK_TREE": str(self.personal)})
        self.assertEqual(self.raw("-C", str(self.personal), "log", "-1", "--format=%ae"), "personal@example.org")

    def test_symlink_and_compatibility_paths(self):
        link = self.home / "shortcut"
        link.symlink_to(self.personal, target_is_directory=True)
        self.assertEqual(self.run_tool("workspace-context", "status", "--name", cwd=link).stdout.strip(), "personal")
        for name in ("projects", "nixos-config"):
            path = self.home / name
            path.mkdir()
            self.assertEqual(self.run_tool("workspace-context", "status", "--name", cwd=path).stdout.strip(), "personal")

    def test_context_conflict_is_rejected(self):
        self.init(self.work)
        self.run_tool("git", "commit", "--allow-empty", "-m", "initial", cwd=self.work)
        linked = self.personal / "agent"
        self.raw("-C", str(self.work), "worktree", "add", "-q", "-b", "conflict", str(linked))
        self.run_tool("workspace-context", "status", cwd=linked, expected=64)

    def test_github_and_aws_routing_sanitizes_inherited_credentials(self):
        inherited = {"GH_TOKEN": "fixture-token", "GITHUB_TOKEN": "fixture-token", "GH_CONFIG_DIR": "/wrong", "GH_HOST": "wrong.example.org", "AWS_PROFILE": "wrong", "AWS_ACCESS_KEY_ID": "fixture", "AWS_SHARED_CREDENTIALS_FILE": "/wrong", "AWS_ENDPOINT_URL_STS": "https://wrong.example.org"}
        self.run_tool("gh", "api", "user", cwd=self.personal, extra=inherited)
        data = json.loads(self.capture.read_text())
        self.assertEqual(data["env"]["GH_CONFIG_DIR"], str(self.home / ".config/gh/personal"))
        self.assertNotIn("GH_TOKEN", data["env"])
        self.assertNotIn("GH_HOST", data["env"])
        self.run_tool("aws", "sts", "get-caller-identity", cwd=self.work, extra=inherited)
        data = json.loads(self.capture.read_text())
        self.assertEqual(data["args"][:2], ["--profile", "work-readonly"])
        self.assertNotIn("AWS_ACCESS_KEY_ID", data["env"])
        self.assertNotIn("AWS_ENDPOINT_URL_STS", data["env"])

    def test_explicit_context_and_fixed_helpers(self):
        command = [sys.executable, SCRIPT, "--config", str(self.config), "gh", "api", "user"]
        self.run_tool("workspace-context", "exec", "personal", "--", *command)
        self.assertTrue(json.loads(self.capture.read_text())["env"]["GH_CONFIG_DIR"].endswith("/personal"))
        self.run_tool("aws-work", "sts", "get-caller-identity")
        self.assertEqual(json.loads(self.capture.read_text())["args"][:2], ["--profile", "work-readonly"])
        self.run_tool("aws", "s3", "rm", "s3://fixture", cwd=self.work, expected=77)
        self.run_tool("aws", "sts", "get-caller-identity", "--profile=wrong", cwd=self.work, expected=77)
        self.run_tool("gh-login", "personal")
        self.assertIn("--skip-ssh-key", json.loads(self.capture.read_text())["args"])

    def test_explicit_scope_reaches_raw_project_git_in_cache_directories(self):
        self.init(self.neutral)
        self.run_tool("workspace-context", "exec", "personal", "--", GIT, "commit", "--allow-empty", "-m", "project Git")
        self.assertEqual(self.raw("log", "-1", "--format=%ae"), "personal@example.org")
        result = self.run_tool("workspace-context", "exec", "work", "--", GIT, "config", "--get-all", "credential.https://github.com.helper")
        self.assertIn("gh-work auth git-credential", result.stdout)

    def test_selected_ssh_key_and_other_hosts(self):
        self.run_tool("git-ssh", "work", "-o", "SendEnv=GIT_PROTOCOL", "git@github.com", "git-upload-pack repo")
        args = json.loads(self.capture.read_text())["args"]
        self.assertIn(str(self.home / ".ssh/work"), args)
        self.assertIn("IdentitiesOnly=yes", args)
        self.assertIn("git@github.com", args)
        for destination in ("github.com-personal", "git@github.com-personal", "github.com"):
            self.run_tool("git-ssh", "personal", destination, "git-upload-pack repo")
            selected = json.loads(self.capture.read_text())["args"]
            self.assertIn("git@github.com", selected)
            self.assertIn(str(self.home / ".ssh/personal"), selected)
        self.run_tool("git-ssh", "personal", "git@github.com-work", expected=77)
        self.run_tool("git-ssh", "neutral", "git@github.com", expected=77)
        self.run_tool("git-ssh", "neutral", "victus", "true")
        self.assertEqual(json.loads(self.capture.read_text())["args"], ["victus", "true"])

    def test_neutral_public_url_and_help_do_not_select_identity(self):
        self.assertEqual(self.run_tool("git", "ls-remote", "--get-url", "https://github.com/NixOS/nixpkgs.git").stdout.strip(), "https://github.com/NixOS/nixpkgs.git")
        self.run_tool("gh", "--version")
        self.run_tool("aws", "--version")

    def test_https_helpers_are_context_selected_without_global_url_rewrite(self):
        for cwd, context in ((self.work, "work"), (self.personal, "personal")):
            value = self.run_tool("git", "config", "--get-all", "credential.https://github.com.helper", cwd=cwd).stdout
            self.assertIn("gh-" + context + " auth git-credential", value)
            self.run_tool("gh-" + context, "auth", "git-credential")
            self.assertTrue(json.loads(self.capture.read_text())["env"]["GH_CONFIG_DIR"].endswith("/" + context))


if __name__ == "__main__":
    unittest.main()
