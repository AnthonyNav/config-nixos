#!/usr/bin/env python3
"""Run the real reconciler against a stateful, replacement-semantics REST fake."""
import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from urllib.parse import unquote, urlparse


def fake_tool(tool, args):
    state_path = Path(os.environ["TEST_SYNCTHING_STATE"])
    state = json.loads(state_path.read_text())
    if tool == "tailscale":
        print(json.dumps({"Peer": {"peer": {"HostName": "victus", "TailscaleIPs": ["100.64.0.2"]}}}))
        return 0
    if tool == "xmllint":
        print("test-api-key")
        return 0
    if tool == "openssl":
        if state.get("offline"):
            return 1
        if args[0] == "s_client":
            print("-----BEGIN CERTIFICATE-----\ntest\n-----END CERTIFICATE-----")
        elif args[0] == "dgst":
            sys.stdout.buffer.write(b"x" * 32)
        return 0
    method, payload, url = "GET", None, ""
    i = 0
    while i < len(args):
        arg = args[i]
        if arg in ("-X", "--data-binary", "-H", "--connect-timeout", "--max-time"):
            value = args[i + 1]
            if arg == "-X":
                method = value
            if arg == "--data-binary":
                payload = json.loads(value)
            i += 2
        else:
            if arg.startswith("http"):
                url = arg
            i += 1
    endpoint = unquote(urlparse(url).path).removeprefix("/rest/")
    if state.get("failCollections") and endpoint == "config/folders":
        return 22
    if endpoint == "system/ping":
        result = {"ping": "pong"}
    elif endpoint == "system/status":
        result = {"myID": "LOCAL"}
    elif endpoint == "svc/deviceid":
        result = {"id": state.get("peerID", "VICTUS")}
    elif endpoint == "config/restart-required":
        result = {"requiresRestart": False}
    elif endpoint == "config/defaults/device":
        result = [] if state.get("badDefaults") == "device" else {"paused": False, "compression": "metadata", "maxRecvKbps": 0}
    elif endpoint == "config/defaults/folder":
        result = [] if state.get("badDefaults") == "folder" else {"versioning": {"type": "", "params": {}}, "fsWatcherEnabled": True, "paused": False}
    else:
        parts = endpoint.split("/")
        collection, object_id = parts[1], parts[2] if len(parts) > 2 else None
        key = "deviceID" if collection == "devices" else "id"
        objects = state[collection]
        existing = next((obj for obj in objects if obj[key] == object_id), None)
        if method == "GET":
            result = objects if object_id is None else existing
        elif method == "POST":
            if collection == "folders" and state.get("requireIgnores"):
                ignore = Path(payload["path"]) / ".stignore"
                if not ignore.is_file() or "# BEGIN fleet-ignore-scope" not in ignore.read_text():
                    return 22
            # Syncthing POST replaces the entire object, not a recursive merge.
            state[collection] = [obj for obj in objects if obj[key] != payload[key]] + [payload]
            result = {}
        elif method == "PATCH":
            if existing is None:
                return 22
            existing.update(payload)
            result = {}
        elif method == "DELETE":
            state[collection] = [obj for obj in objects if obj[key] != object_id]
            result = {}
        else:
            return 22
    if method != "GET":
        state["writes"].append([method, endpoint, payload])
        state_path.write_text(json.dumps(state))
    print(json.dumps(result))
    return 0


class ReconcileTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for tool in ("curl", "tailscale", "openssl", "xmllint"):
            stub = self.bin / tool
            stub.write_text(f'#!{sys.executable}\nimport runpy, sys\nsys.argv = [{str(Path(__file__).resolve())!r}, "--fake-tool", {tool!r}, *sys.argv[1:]]\nrunpy.run_path(sys.argv[0], run_name="__main__")\n')
            stub.chmod(0o755)
        self.folder_path = self.root / "data"
        self.folder_path.mkdir()
        (self.folder_path / "keep.txt").write_text("personal data")
        (self.root / "config.xml").write_text("test config")
        self.state_path = self.root / "state.json"
        self.state = {
            "devices": [
                {"deviceID": "VICTUS", "name": "fleet:victus", "addresses": ["dynamic"], "paused": True, "compression": "always", "maxRecvKbps": 123},
                {"deviceID": "OLD", "name": "fleet:thinkpad", "addresses": ["dynamic"]},
                {"deviceID": "FRIEND", "name": "personal peer", "addresses": ["dynamic"]},
            ],
            "folders": [
                {"id": "fleet-shared", "label": "old", "path": str(self.folder_path), "type": "sendreceive", "paused": True,
                 "versioning": {"type": "staggered", "params": {"maxAge": "31536000"}}, "fsWatcherEnabled": False, "rescanIntervalS": 7200,
                 "devices": [{"deviceId": "OLD"}, {"deviceId": "VICTUS", "encryptionPassword": "local-test-value"}, {"deviceId": "FRIEND"}]},
                {"id": "personal", "path": str(self.folder_path), "devices": [{"deviceId": "FRIEND"}]},
            ],
            "writes": [],
        }
        self.folders = [{"id": "fleet-shared", "label": "Fleet Shared", "path": str(self.folder_path), "type": "sendreceive", "hosts": ["desktop", "victus"]}]

    def run_script(self, *args, expected=0):
        self.state_path.write_text(json.dumps(self.state))
        env = os.environ | {
            "PATH": str(self.bin) + os.pathsep + os.environ["PATH"],
            "TEST_SYNCTHING_STATE": str(self.state_path),
            "SYNCTHING_CONFIG_DIR": str(self.root), "SYNCTHING_FLEET_HOST": "desktop",
            "SYNCTHING_FLEET_PEERS_JSON": '["victus"]',
            "SYNCTHING_FLEET_FOLDERS_JSON": json.dumps(self.folders),
            "SYNCTHING_FLEET_IGNORE_HELPER": str(Path(RECONCILER).with_name("syncthing-ignores.py")),
        }
        result = subprocess.run(["bash", RECONCILER, *args], env=env, capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, expected, result.stderr)
        self.state = json.loads(self.state_path.read_text())

    def test_preserves_local_folder_and_device_settings(self):
        before = copy.deepcopy(self.state)
        self.run_script()
        folder = next(f for f in self.state["folders"] if f["id"] == "fleet-shared")
        for key in ("versioning", "fsWatcherEnabled", "rescanIntervalS", "paused"):
            self.assertEqual(folder[key], before["folders"][0][key])
        peer = next(d for d in self.state["devices"] if d["deviceID"] == "VICTUS")
        for key in ("compression", "maxRecvKbps", "paused"):
            self.assertEqual(peer[key], before["devices"][0][key])
        self.assertEqual(folder["devices"], [{"deviceId": "FRIEND"}, {"deviceId": "LOCAL"}, {"deviceId": "VICTUS", "encryptionPassword": "local-test-value"}])
        self.assertEqual(self.state["folders"][1], before["folders"][1])
        self.assertEqual(next(d for d in self.state["devices"] if d["deviceID"] == "FRIEND"), before["devices"][2])

    def test_retirement_preserves_data(self):
        self.run_script()
        self.assertNotIn("OLD", [d["deviceID"] for d in self.state["devices"]])
        self.assertEqual((self.folder_path / "keep.txt").read_text(), "personal data")

    def test_offline_peer_leaves_configuration_unchanged(self):
        self.state["offline"] = True
        before = copy.deepcopy(self.state)
        self.run_script(expected=75)
        self.assertEqual(self.state, before)

    def test_device_identity_rotation(self):
        self.state["peerID"] = "REPLACEMENT"
        self.run_script()
        self.assertEqual({d["deviceID"] for d in self.state["devices"]}, {"REPLACEMENT", "FRIEND"})
        folder = next(f for f in self.state["folders"] if f["id"] == "fleet-shared")
        self.assertEqual({d["deviceId"] for d in folder["devices"]}, {"REPLACEMENT", "FRIEND", "LOCAL"})

    def test_creation_uses_defaults(self):
        self.state.update(devices=[], folders=[])
        self.run_script()
        self.assertEqual(self.state["folders"][0]["versioning"]["type"], "")
        self.assertEqual(self.state["devices"][0]["compression"], "metadata")
        self.assertTrue(all(write[0] == "POST" for write in self.state["writes"]))

    def test_second_run_performs_no_writes(self):
        self.run_script()
        self.state["writes"] = []
        self.run_script()
        self.assertEqual(self.state["writes"], [])

    def test_check_mode_performs_no_writes(self):
        before = copy.deepcopy(self.state)
        self.run_script("--check")
        self.assertEqual(self.state, before)

    def test_failed_preflight_performs_no_writes(self):
        self.state["failCollections"] = True
        self.run_script(expected=75)
        self.assertEqual(self.state["writes"], [])

    def test_invalid_defaults_perform_no_writes(self):
        for kind in ("device", "folder"):
            with self.subTest(kind=kind):
                self.state["badDefaults"] = kind
                before = copy.deepcopy(self.state)
                self.run_script(expected=75)
                self.assertEqual(self.state, before)

    def workspace_folders(self):
        self.folders = [{"id": f"fleet-{name}", "label": name, "path": str(self.root / "Workspace" / name), "type": "sendreceive", "hosts": ["desktop", "victus"], "migrationFrom": "fleet-shared", "ignorePatterns": ["/repos", "/worktrees", ".git", ".env", "node_modules", ".stignore*"]} for name in ("work", "personal")]
        self.state["requireIgnores"] = True

    def test_workspace_migration_prepares_ignores_before_registration(self):
        self.workspace_folders()
        before = copy.deepcopy(self.state)
        self.run_script()
        managed = [folder for folder in self.state["folders"] if folder["id"].startswith("fleet-")]
        self.assertEqual({folder["id"] for folder in managed}, {"fleet-work", "fleet-personal"})
        for folder in managed:
            self.assertEqual(folder["versioning"], before["folders"][0]["versioning"])
            self.assertTrue(folder["paused"])
            self.assertNotIn("FRIEND", {d["deviceId"] for d in folder["devices"]})
            ignore = Path(folder["path"]) / ".stignore"
            text = ignore.read_text()
            self.assertLess(text.index(".env"), text.index("!/shared"))
            self.assertEqual(ignore.stat().st_mode & 0o777, 0o600)
        self.assertEqual((self.folder_path / "keep.txt").read_text(), "personal data")
        retired = list(self.root.glob("fleet-retired-fleet-shared.*.json"))
        self.assertEqual(len(retired), 1)
        self.assertEqual(retired[0].stat().st_mode & 0o777, 0o600)
        self.assertEqual(json.loads(retired[0].read_text()), before["folders"][0])
        self.state["writes"] = []
        self.run_script()
        self.assertEqual(self.state["writes"], [])

    def test_ignore_preflight_failure_leaves_all_folders_and_rest_unchanged(self):
        self.workspace_folders()
        root = Path(self.folders[1]["path"])
        root.mkdir(parents=True)
        (root / ".stignore").write_text("!/repos\n")
        before = copy.deepcopy(self.state)
        self.run_script(expected=78)
        self.assertEqual(self.state, before)
        self.assertFalse(Path(self.folders[0]["path"]).exists())
        self.assertEqual((root / ".stignore").read_text(), "!/repos\n")

    def test_preserves_positive_user_ignores_and_rejects_owned_edits(self):
        self.workspace_folders()
        root = Path(self.folders[0]["path"])
        root.mkdir(parents=True)
        (root / ".stignore").write_text("shared/private-notes\n")
        self.run_script()
        text = (root / ".stignore").read_text()
        self.assertLess(text.index("shared/private-notes"), text.index("!/shared"))
        self.assertEqual((root / ".stignore.fleet-backup").read_text(), "shared/private-notes\n")
        (root / ".stignore").write_text(text.replace("/repos\n", "!/repos\n"))
        self.state["writes"] = []
        self.run_script(expected=78)
        self.assertEqual(self.state["writes"], [])


if __name__ == "__main__":
    if sys.argv[1] == "--fake-tool":
        sys.exit(fake_tool(sys.argv[2], sys.argv[3:]))
    RECONCILER = sys.argv.pop(1)
    unittest.main()
