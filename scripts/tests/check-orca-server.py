#!/usr/bin/env python3
"""Orca service boundaries using isolated processes and synthetic runtime evidence."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS = Path(sys.argv.pop(1)).resolve()
spec = importlib.util.spec_from_file_location("orca_server", SCRIPTS / "orca-server.py")
server = importlib.util.module_from_spec(spec)
spec.loader.exec_module(server)


class OrcaServerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.invocation = "a" * 32
        self.identity = {"verified": True, "service_owned": True, "unit": server.UNIT}
        self.ready = {"type": "orca_server_ready", "schemaVersion": 1,
                      "runtimeId": "test-runtime",
                      "boundEndpoint": "ws://0.0.0.0:6768", "advertisedEndpoint": "ws://100.64.1.2:6768",
                      "pairing": {"available": True, "url": "orca://pair?code=private-fixture", "qr": "private-qr"}}

    def execute(self, args, timeout=4, env=None):
        command = args[0]
        if command == "systemctl":
            return f"LoadState=loaded\nActiveState=active\nSubState=running\nInvocationID={self.invocation}\nMainPID=42\nControlGroup=/app.slice/orca-serve.service\n"
        if command == "loginctl":
            return "yes\n"
        if command == "tailscale":
            return "100.64.1.2\n" if args[1] == "ip" else json.dumps({"BackendState": "Running", "Self": {"Online": True}})
        if command == "journalctl":
            if self.identity["unit"] == server.UNIT:
                self.assertIn(f"_SYSTEMD_INVOCATION_ID={self.invocation}", args)
            else:
                self.assertIn("app-orca-42.scope", args)
            return json.dumps(self.ready)
        if command == "orca-ide":
            self.assertEqual(env["HOME"], str(self.home))
            self.assertEqual(env["XDG_CONFIG_HOME"], str(self.home / ".config"))
            for key in ("ORCA_USER_DATA_PATH", "ORCA_ENVIRONMENT", "ORCA_PAIRING_CODE", "ORCA_CLI_CWD"):
                self.assertNotIn(key, env)
            return json.dumps({"ok": True, "result": {"app": {"pid": 42}, "runtime": {"reachable": True, "state": "ready", "runtimeId": "test-runtime"}}})
        if command == "ss":
            return 'LISTEN 0 511 0.0.0.0:6768 users:(("orca-ide",pid=42,fd=21))'
        raise AssertionError(args)

    def probe(self):
        with patch.object(server, "run", side_effect=self.execute), patch.object(server.shutil, "which", return_value="/fixture/tool"), patch.object(server, "runtime_identity", return_value=self.identity), patch.object(server, "daemon_scopes", return_value={"verified": True, "units": ["orca-daemon-test.scope"]}):
            return server.probe({"mode": "headless", "port": 6768}, self.home)

    def test_policy_off_does_not_probe_or_authenticate(self):
        with patch.object(server, "run", side_effect=AssertionError("Unexpected runtime access")):
            self.assertEqual(server.probe({"mode": "off"}, self.home), {"mode": "off", "probed": False})

    def test_health_requires_current_invocation_listener_and_declared_endpoint(self):
        data = self.probe()
        self.assertTrue(data["healthy"])
        self.assertNotIn("private-fixture", json.dumps(data))
        self.ready["boundEndpoint"] = "ws://0.0.0.0:6769"
        self.assertFalse(self.probe()["healthy"])
        self.ready["boundEndpoint"] = "ws://0.0.0.0:6768"
        self.ready["advertisedEndpoint"] = "ws://100.64.1.99:6768"
        self.assertFalse(self.probe()["healthy"])

    def test_invalid_or_old_readiness_does_not_prove_health(self):
        self.ready["schemaVersion"] = 2
        self.assertFalse(self.probe()["healthy"])
        with patch.object(server, "run", return_value='{"pairing":"private-fixture"}'):
            self.assertEqual(server.readiness("", "test-runtime"), {})
        self.ready["schemaVersion"] = 1
        self.ready["runtimeId"] = "stale-runtime"
        self.assertFalse(self.probe()["healthy"])

    def test_legacy_scope_exposes_only_correlated_offer_and_requires_migration(self):
        self.identity = {"verified": True, "service_owned": False, "unit": "app-orca-42.scope"}
        data = self.probe()
        self.assertEqual(data["endpoint"], "ws://100.64.1.2:6768")
        self.assertTrue(data["pairing_available"])
        self.assertFalse(data["healthy"])
        self.assertFalse(data["service_owns_runtime"])
        self.ready["runtimeId"] = "stale-runtime"
        self.assertIsNone(self.probe()["endpoint"])
        self.identity["verified"] = False
        self.assertFalse(self.probe()["pairing_available"])

    def test_runtime_identity_requires_managed_executable_and_matching_kernel_group(self):
        proc = self.home / "runtime-proc"
        process = proc / "42"
        process.mkdir(parents=True)
        (process / "cmdline").write_bytes(b"orca-ide\0--serve\0--serve-json\0")
        (process / "exe").symlink_to("/nix/store/" + "a" * 32 + "-orca-ide-unwrapped-1.4.220/app/orca-ide")
        group = "/app.slice/orca-serve.service"
        (process / "cgroup").write_text(f"0::{group}\n")
        service = {"MainPID": "42", "ControlGroup": group}
        self.assertTrue(server.runtime_identity(42, service, proc)["service_owned"])
        service["MainPID"] = "41"
        self.assertTrue(server.runtime_identity(42, service, proc)["verified"])
        self.assertFalse(server.runtime_identity(42, service, proc)["service_owned"])
        (process / "cgroup").write_text("0::/app.slice/app-orca-42.scope\n")
        self.assertTrue(server.runtime_identity(42, service, proc)["verified"])
        self.assertFalse(server.runtime_identity(42, service, proc)["service_owned"])
        # Chromium can move the very same service MainPID into a portal scope.
        # Electron may rewrite argv; the managed live executable remains proof.
        service["MainPID"] = "42"
        (process / "cmdline").write_bytes(b"orca\0")
        self.assertTrue(server.runtime_identity(42, service, proc)["service_owned"])
        (process / "cgroup").write_text("0::/app.slice/app-orca-99.scope\n")
        self.assertFalse(server.runtime_identity(42, service, proc)["verified"])
        (process / "exe").unlink()
        (process / "exe").symlink_to("/usr/bin/another-program")
        self.assertFalse(server.runtime_identity(42, service, proc)["verified"])

    def test_chromium_scope_is_healthy_when_runtime_is_the_service_main_pid(self):
        self.identity = {"verified": True, "service_owned": True, "unit": "app-orca-42.scope"}
        data = self.probe()
        self.assertTrue(data["healthy"])
        self.assertEqual(data["readiness_source"], "app-orca-42.scope")

    def test_default_logs_hide_pairing_tokens_and_query_parameters(self):
        for line in (json.dumps(self.ready), 'Pairing URL: orca://pair?code=private-fixture',
                     '{"nested":{"accessToken":"private-fixture"}}', 'connect https://example.org?code=private-fixture'):
            self.assertNotIn("private-fixture", server.redacted(line))
            self.assertNotIn("private-qr", server.redacted(line))
        self.assertEqual(server.redacted("Orca: waiting for Tailscale connectivity.\n"), "Orca: waiting for Tailscale connectivity.")

    def test_empty_terminal_census_requires_explicit_complete_host_scope(self):
        value = {"ok": True, "result": {"terminals": [], "truncated": False,
                                       "hostScope": {"hostIds": ["local"], "omittedHostIds": []}}}
        self.assertTrue(server.empty_census(value))
        for omissions in (["ssh:work"], ["unknown"]):
            value["result"]["hostScope"]["omittedHostIds"] = omissions
            self.assertFalse(server.empty_census(value))
        value["result"]["hostScope"]["omittedHostIds"] = ["runtime:paired-other-device"]
        self.assertTrue(server.empty_census(value))
        value["result"]["truncated"] = True
        self.assertFalse(server.empty_census(value))
        self.assertFalse(server.empty_census({"ok": True, "result": {"terminals": []}}))

    def test_scope_evidence_checks_pid_identity_and_actual_kernel_cgroup(self):
        profile = self.home / ".config/orca/daemon"
        profile.mkdir(parents=True)
        proc = self.home / "proc"
        process = proc / "42"
        process.mkdir(parents=True)
        boot = proc / "sys/kernel/random/boot_id"
        boot.parent.mkdir(parents=True)
        boot.write_text("test-boot")
        fields = ["S"] + ["0"] * 18 + ["123"]
        (process / "stat").write_text("42 (Orca daemon) " + " ".join(fields))
        (process / "cmdline").write_bytes(b"daemon-entry.js\0" + str(profile / "daemon-v39.sock").encode() + b"\0")
        (process / "cgroup").write_text("0::/user.slice/user-1000.slice/user@1000.service/app.slice/orca-daemon-test.scope\n")
        record = {"pid": 42, "linuxStartTicks": "123", "bootId": "test-boot"}
        pidfile = profile / "daemon-v39.pid"
        pidfile.write_text(json.dumps(record))
        self.assertTrue(server.daemon_scopes(self.home, proc)["verified"])
        # A persisted claim is insufficient when the live process is unscoped.
        record["cgroupUnit"] = "orca-daemon-test.scope"
        pidfile.write_text(json.dumps(record))
        (process / "cgroup").write_text("0::/app.slice/orca-serve.service\n")
        self.assertFalse(server.daemon_scopes(self.home, proc)["verified"])
        (process / "cgroup").write_text("0::/app.slice/orca-daemon-test.scope\n")
        record["linuxStartTicks"] = "999"
        pidfile.write_text(json.dumps(record))
        self.assertFalse(server.daemon_scopes(self.home, proc)["verified"])

    def test_restart_defers_when_isolation_and_census_are_unverifiable(self):
        data = {"service": {"ActiveState": "active"}, "runtime": {"reachable": True}, "service_owns_runtime": True, "daemon_scope": {"verified": False}}
        with patch.object(sys, "argv", ["orca-server", "restart"]), patch.object(server, "probe", return_value=data), patch.object(server, "run", return_value=None), patch.object(server.subprocess, "run", side_effect=AssertionError("Restart must not run")):
            self.assertEqual(server.main(), 1)

    def test_restart_never_stops_a_legacy_detached_runtime_implicitly(self):
        data = {"service": {"ActiveState": "active"}, "runtime": {"reachable": True}, "service_owns_runtime": False, "daemon_scope": {"verified": True}}
        with patch.object(sys, "argv", ["orca-server", "restart"]), patch.object(server, "probe", return_value=data), patch.object(server.subprocess, "run", side_effect=AssertionError("Restart must not run")):
            self.assertEqual(server.main(), 1)

    def test_boot_wrapper_waits_for_vpn_clears_display_and_preserves_exit_three(self):
        binary = self.home / "bin"
        binary.mkdir()
        capture = self.home / "capture.json"
        counter = self.home / "counter"
        driver = f'#!{sys.executable}\nimport json, os, sys\nfrom pathlib import Path\n'
        tailscale = driver + f'counter=Path({str(counter)!r})\ncount=int(counter.read_text()) if counter.exists() else 0\nif sys.argv[1]=="status":\n counter.write_text(str(count+1))\n print(json.dumps({{"BackendState":"Running" if count else "Starting", "Self":{{"Online":bool(count)}}}}))\nelse: print("100.64.1.2")\n'
        fake = driver + f'Path({str(capture)!r}).write_text(json.dumps({{"args":sys.argv[1:], "display":os.environ.get("DISPLAY"), "wayland":os.environ.get("WAYLAND_DISPLAY"), "software":os.environ.get("LIBGL_ALWAYS_SOFTWARE"), "dbus":os.environ.get("DBUS_SESSION_BUS_ADDRESS")}}))\nsys.exit(3)\n'
        for name, text in (("tailscale", tailscale), ("orca-ide", fake), ("ss", "#!/bin/sh\nexit 0\n"), ("sleep", "#!/bin/sh\nexit 0\n")):
            path = binary / name
            path.write_text(text)
            path.chmod(0o755)
        environment = os.environ | {"PATH": str(binary) + ":" + os.environ["PATH"], "DISPLAY": ":1", "WAYLAND_DISPLAY": "wayland-1", "DBUS_SESSION_BUS_ADDRESS": "unix:path=test-bus"}
        result = subprocess.run([shutil.which("bash"), "-euo", "pipefail", str(SCRIPTS / "orca-serve-fleet.sh"), str(binary / "orca-ide"), "6768"], env=environment, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 3, result.stderr)
        data = json.loads(capture.read_text())
        self.assertEqual(data["args"], ["--serve-port", "6768", "--serve-pairing-address", "100.64.1.2", "--serve-json"])
        self.assertIsNone(data["display"])
        self.assertIsNone(data["wayland"])
        self.assertEqual(data["software"], "1")
        self.assertEqual(data["dbus"], "unix:path=test-bus")
        self.assertGreaterEqual(int(counter.read_text()), 2)
        (binary / "ss").write_text("#!/bin/sh\nprintf '%s\\n' occupied\n")
        capture.unlink()
        result = subprocess.run([shutil.which("bash"), "-euo", "pipefail", str(SCRIPTS / "orca-serve-fleet.sh"), str(binary / "orca-ide"), "6768"], env=environment, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 78)
        self.assertFalse(capture.exists())


if __name__ == "__main__":
    unittest.main()
