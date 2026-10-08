#!/usr/bin/env python3
"""Real Git publication/receipt scenarios in disposable work and personal homes."""
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
GIT = shutil.which("git")
LSOF = shutil.which("lsof")
sys.path.insert(0, str(SCRIPTS))
spec = importlib.util.spec_from_file_location("receiver", SCRIPTS / "workspace-sync.py")
receiver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(receiver)


class ReceiverTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.home = self.root / "home"
        self.home.mkdir()
        self.source = self.root / "source"
        self.remote = self.root / "remote.git"
        self.checkout = self.home / "Workspace/personal/example/repos/app"
        self.checkout.parent.mkdir(parents=True)
        self.env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
        self.env.update(HOME=str(self.home), GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL="/dev/null",
                        GIT_AUTHOR_NAME="Fixture", GIT_COMMITTER_NAME="Fixture",
                        GIT_AUTHOR_EMAIL="fixture@example.test", GIT_COMMITTER_EMAIL="fixture@example.test")
        self.git(self.root, "init", "--bare", "--initial-branch=main", str(self.remote))
        self.git(self.root, "clone", str(self.remote), str(self.source))
        (self.source / "app.txt").write_text("initial\n")
        (self.source / ".gitignore").write_text("ignored.txt\n")
        self.publish()
        self.git(self.root, "clone", str(self.remote), str(self.checkout))
        self.initial = self.head()
        self.lsof = self.root / "lsof"
        self.lsof.write_text(f'#!{sys.executable}\nimport sys\nsys.stdout.buffer.write({b"p12345\0n" + str(self.home).encode() + b"\0\n"!r})\n')
        self.lsof.chmod(0o755)
        self.policy = self.root / "policy.json"
        self.config = {"homeDirectory": str(self.home), "policy": {"default": "neutral", "identities": {
            context: {"git": {"name": "Fixture " + context, "email": context + "@example.test"},
                      "roots": ["Workspace/" + context], "aws": {"profile": context + "-readonly"},
                      "sshKey": ".ssh/id_" + context, "github": {"alias": "github.com-" + context}}
            for context in ("work", "personal")}}, "binaries": {"git": GIT, "gh": "/not-used/gh", "aws": "/not-used/aws", "ssh": "/not-used/ssh", "lsof": str(self.lsof)}}
        self.policy.write_text(json.dumps(self.config))
        self.registry = self.home / ".config/fleet/workspace-sync.json"
        self.receipts = self.home / ".local/state/fleet/workspace-sync/receipts.json"
        self.command("register", str(self.checkout))

    def git(self, path, *arguments):
        result = subprocess.run([GIT, "-c", "core.hooksPath=/dev/null", "-C", str(path), *arguments],
                                env=self.env, capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def command(self, *arguments, expected=0, env=None):
        result = subprocess.run([sys.executable, "-B", str(SCRIPTS / "workspace-context.py"), "--config", str(self.policy), "workspace-sync", *arguments],
                                env=self.env | (env or {}), cwd=self.home, capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, expected, result.stderr)
        return result

    def publish(self, content=None, name="app.txt"):
        if content is not None:
            (self.source / name).write_text(content)
        self.git(self.source, "add", "--all")
        self.git(self.source, "commit", "-m", "Published fixture")
        self.git(self.source, "push", "origin", "main")
        return self.git(self.source, "rev-parse", "HEAD")

    def head(self):
        return self.git(self.checkout, "rev-parse", "HEAD")

    def run_receiver(self):
        self.command("run", "--json")
        return json.loads(self.receipts.read_text())[0]

    def test_receives_published_changes_and_is_idempotent(self):
        target = self.publish("from Desktop/mobile\n")
        receipt = self.run_receiver()
        self.assertEqual(receipt["result"], "updated")
        self.assertEqual(receipt["before"], self.initial)
        self.assertEqual(receipt["after"], target)
        self.assertEqual(self.head(), target)
        self.assertEqual((self.checkout / "app.txt").read_text(), "from Desktop/mobile\n")
        self.assertEqual(self.run_receiver()["result"], "current")

    def test_tracked_staged_and_untracked_edits_stop_receipt(self):
        self.publish("published\n")
        for kind in ("tracked", "staged", "untracked"):
            with self.subTest(kind=kind):
                path = self.checkout / ("local.txt" if kind == "untracked" else "app.txt")
                path.write_text("local work\n")
                if kind == "staged":
                    self.git(self.checkout, "add", "app.txt")
                before = self.git(self.checkout, "status", "--porcelain=v1")
                self.assertEqual(self.run_receiver()["result"], "dirty")
                self.assertEqual(self.head(), self.initial)
                self.assertEqual(path.read_text(), "local work\n")
                self.assertEqual(self.git(self.checkout, "status", "--porcelain=v1"), before)
                # Fixture cleanup only; the receiver never invokes reset/stash.
                if kind == "untracked":
                    path.unlink()
                else:
                    self.git(self.checkout, "restore", "--source=HEAD", "--staged", "--worktree", "app.txt")

    def test_ignored_file_collision_does_not_overwrite_local_data(self):
        (self.source / "ignored.txt").write_text("published\n")
        self.git(self.source, "add", "--force", "ignored.txt")
        self.publish("published app\n")
        (self.checkout / "ignored.txt").write_text("private local data\n")
        self.assertEqual(self.run_receiver()["result"], "apply-blocked")
        self.assertEqual(self.head(), self.initial)
        self.assertEqual((self.checkout / "ignored.txt").read_text(), "private local data\n")
        self.assertEqual(self.git(self.checkout, "status", "--porcelain=v1"), "")

    def test_ahead_and_diverged_branches_are_never_rewritten(self):
        (self.checkout / "local.txt").write_text("unpublished\n")
        self.git(self.checkout, "add", "local.txt")
        self.git(self.checkout, "commit", "-m", "Local work")
        local = self.head()
        self.assertEqual(self.run_receiver()["result"], "ahead")
        self.publish("different published work\n")
        self.assertEqual(self.run_receiver()["result"], "diverged")
        self.assertEqual(self.head(), local)

    def test_different_branch_and_detached_head_are_preserved(self):
        self.publish("new\n")
        self.git(self.checkout, "switch", "-c", "feature/local")
        self.assertEqual(self.run_receiver()["result"], "branch-changed")
        self.git(self.checkout, "switch", "--detach")
        self.assertEqual(self.run_receiver()["result"], "branch-changed")
        self.assertEqual(self.head(), self.initial)

    def test_git_operation_and_lock_stop_receipt(self):
        self.publish("new\n")
        for marker in ("index.lock", "MERGE_HEAD", "rebase-merge"):
            path = self.checkout / ".git" / marker
            path.write_text("fixture\n")
            self.assertEqual(self.run_receiver()["result"], "git-operation")
            self.assertEqual(self.head(), self.initial)
            path.unlink()

    def test_hold_resume_and_unregister(self):
        target = self.publish("new\n")
        self.command("hold", str(self.checkout))
        self.assertEqual(self.run_receiver()["result"], "held")
        self.assertEqual(self.head(), self.initial)
        self.command("resume", str(self.checkout))
        self.assertEqual(self.run_receiver()["result"], "updated")
        self.assertEqual(self.head(), target)
        self.command("unregister", str(self.checkout))
        self.command("run", "--json")
        self.assertEqual(json.loads(self.receipts.read_text()), [])

    def test_missing_remote_keeps_checkout_and_does_not_reveal_stderr(self):
        self.remote.rename(self.root / "offline.git")
        receipt = self.run_receiver()
        self.assertEqual(receipt["result"], "fetch-unavailable")
        self.assertEqual(self.head(), self.initial)
        self.assertNotIn("remote.git", json.dumps(receipt))

    def test_remote_change_requires_reregistration(self):
        self.git(self.checkout, "remote", "set-url", "origin", str(self.root / "other.git"))
        self.assertEqual(self.run_receiver()["result"], "registration-changed")
        self.assertEqual(self.head(), self.initial)

    def test_context_mismatch_cannot_be_registered(self):
        self.command("unregister", str(self.checkout))
        self.command("register", str(self.checkout), "--context", "work", expected=64)
        self.assertEqual(json.loads(self.registry.read_text())["repositories"], [])

    def test_credential_bearing_url_is_rejected_without_echoing_it(self):
        self.command("unregister", str(self.checkout))
        self.git(self.checkout, "remote", "set-url", "origin", "https://private-fixture@github.com/example/app.git")
        result = self.command("register", str(self.checkout), expected=64)
        self.assertNotIn("private-fixture", result.stdout + result.stderr)

    def test_ambient_git_directory_and_identity_do_not_redirect_receipt(self):
        target = self.publish("new\n")
        result = self.command("run", "--json", env={"GIT_DIR": str(self.source / ".git"), "GIT_WORK_TREE": str(self.source),
                              "FLEET_CONTEXT_OVERRIDE": "work", "GH_TOKEN": "private-fixture"})
        self.assertEqual(json.loads(result.stdout)[0]["result"], "updated")
        self.assertEqual(self.head(), target)
        self.assertNotIn("private-fixture", result.stdout + result.stderr)

    def test_hooks_are_not_executed(self):
        hook = self.checkout / ".git/hooks/post-merge"
        marker = self.root / "hook-ran"
        hook.write_text(f"#!/bin/sh\ntouch '{marker}'\n")
        hook.chmod(0o755)
        self.publish("new\n")
        self.assertEqual(self.run_receiver()["result"], "updated")
        self.assertFalse(marker.exists())

    def test_busy_or_unverified_activity_defers_apply_but_fetches(self):
        target = self.publish("new\n")
        self.lsof.write_text(f'#!{sys.executable}\nimport sys\nsys.stdout.buffer.write({b"p12345\0n" + str(self.checkout).encode() + b"\0\n"!r})\n')
        receipt = self.run_receiver()
        self.assertEqual(receipt["result"], "busy")
        self.assertEqual(receipt["fetched"], target)
        self.assertEqual(self.head(), self.initial)
        self.lsof.write_text("#!/bin/sh\nexit 1\n")
        self.assertEqual(self.run_receiver()["result"], "activity-unverified")

    def test_registry_and_receipts_stay_private_and_outside_shared_roots(self):
        self.run_receiver()
        for path in (self.registry, self.receipts):
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            self.assertNotIn("Workspace", path.relative_to(self.home).parts)
        self.assertNotIn("url", self.command("status", "--json").stdout)

    def test_symlink_registry_cannot_write_another_file(self):
        victim = self.root / "victim.json"
        victim.write_text(self.registry.read_text())
        self.registry.unlink()
        self.registry.symlink_to(victim)
        before = victim.read_text()
        self.command("hold", str(self.checkout), expected=64)
        self.assertEqual(victim.read_text(), before)

    @unittest.skipUnless(LSOF, "native lsof not available")
    def test_native_cwd_census_detects_a_live_project_process(self):
        child = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(30)"], cwd=self.checkout)
        try:
            self.assertEqual(receiver.activity({"binaries": {"lsof": LSOF}}, self.checkout), "busy")
        finally:
            child.terminate()
            child.wait(timeout=5)


if __name__ == "__main__":
    unittest.main()
