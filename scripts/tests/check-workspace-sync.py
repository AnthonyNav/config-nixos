#!/usr/bin/env python3
"""Two isolated real Syncthing peers: documents arrive; code and state never do."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import urllib.request
import xml.etree.ElementTree as ET

spec = importlib.util.spec_from_file_location("ignores", sys.argv[1])
ignores = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ignores)
policy = json.loads(Path(sys.argv[2]).read_text())
binary = sys.argv[3] if len(sys.argv) > 3 else shutil.which("syncthing")
allowed = ["shared/legacy.txt", "cello/HANDOFF.md", "cello/HANDOFF.sync-conflict-fixture.md",
           "cello/docs/notes.md", "cello/assets/image.png", "other/docs/nested/spec.txt"]
blocked = ["cello/repos/backend/README.md", "cello/worktrees/task/main.py", "repos/legacy/main.py",
           "cello/docs/repos/secondary/README.md", "cello/docs/.env", "cello/docs/secret.txt",
           "cello/.orca/state.json", "cello/.fleet-workspace.lock", "cello/unshared.md",
           "cello/docs/private-notes.md", "cello/assets/.aws/credentials"]
# Exercise the mandatory denials before every document allowlist, including
# nested paths and mixed case on case-sensitive peers. Contents are text fixtures,
# never actual signing keys, passwords or provisioning data.
signing_names = ["release.jks", "upload.keystore", "distribution.p12", "distribution.pfx",  # gitleaks:allow - harmless fixture filenames
                 "App.mobileprovision", "App.provisionprofile", "key.properties",
                 "AuthKey_fixture.p8", "service.pem", "service.key"]
for scope in ("shared", "cello/docs", "cello/assets"):
    blocked.extend(f"{scope}/signing-fixtures/{name}" for name in signing_names)
    blocked.extend(f"{scope}/signing-fixtures/nested/{name.upper()}" for name in signing_names)
    # Public service configuration and signing instructions are not private keys.
    # Do not exclude all JSON, certificates, or files named after provisioning.
    allowed.extend(f"{scope}/signing-fixtures/{name}" for name in
                   ("google-services.json", "certificate.cer", "provisioning.md", "key.properties.example"))


def port():
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        return probe.getsockname()[1]


def request(peer, path, data=None):
    content = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(f'http://127.0.0.1:{peer["api"]}/rest/{path}', data=content,
                                 headers={"X-API-Key": "fleet-loopback-fixture", "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=2) as response:
        raw = response.read()
        return json.loads(raw) if raw else None


def wait_for(predicate, processes, description):
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        if any(process.poll() is not None for process in processes):
            raise AssertionError("Isolated Syncthing process exited unexpectedly")
        try:
            if predicate():
                return
        except (OSError, ValueError):
            pass
        time.sleep(0.1)
    raise AssertionError(description)


with tempfile.TemporaryDirectory(prefix="fleet-sync-check-") as temporary:
    # macOS exposes its temporary directory through /var -> /private/var. Keep
    # the fixture canonical so the production workspace symlink guard still runs.
    root = Path(temporary).resolve()
    environment = os.environ | {"HOME": str(root), "STNOUPGRADE": "1", "STNORESTART": "1", "GOMAXPROCS": "2"}
    peers = [{"config": root / name / "config", "folder": root / name / "workspace", "api": port(), "listen": port()} for name in ("a", "b")]
    for peer in peers:
        peer["folder"].mkdir(parents=True)
        peer["config"].mkdir(parents=True)
        subprocess.run([binary, "generate", "--home", str(peer["config"]), "--no-port-probing"],
                       env=environment, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True, timeout=15)
        peer["tree"] = ET.parse(peer["config"] / "config.xml")
        peer["id"] = peer["tree"].getroot().find("device").get("id")
        (peer["folder"] / ".stfolder").mkdir()
        # Upgrade the actual PR #77 ownership shape before peer registration.
        old = {"deny": "/repos\n/worktrees\n.git\n.env\n", "scope": "!/shared\n!/shared/**\n*\n"}
        (peer["folder"] / ".stignore").write_text(ignores.block("deny", old["deny"]) +
                                                "/cello/docs/private-notes.md\n" +
                                                ignores.block("scope", old["scope"]))
        (peer["folder"] / ".stignore.fleet-state").write_text(json.dumps(old))
        ignores.prepare([{"path": str(peer["folder"]), "ignorePatterns": policy["ignorePatterns"]}])
    for relative in allowed + blocked:
        path = peers[0]["folder"] / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("harmless fixture: " + relative)
    for index, peer in enumerate(peers):
        other = peers[1 - index]
        config = peer["tree"].getroot()
        for folder in list(config.findall("folder")):
            config.remove(folder)
        device = ET.SubElement(config, "device", {"id": other["id"], "name": "isolated-peer"})
        ET.SubElement(device, "address").text = f'tcp://127.0.0.1:{other["listen"]}'
        folder = ET.SubElement(config, "folder", {"id": "fixture", "path": str(peer["folder"]), "type": "sendreceive",
                                                "rescanIntervalS": "0", "fsWatcherEnabled": "false"})
        for device_id in (peer["id"], other["id"]):
            ET.SubElement(folder, "device", {"id": device_id})
        gui = config.find("gui")
        gui.set("enabled", "true")
        gui.find("address").text = f'127.0.0.1:{peer["api"]}'
        gui.find("apikey").text = "fleet-loopback-fixture"
        options = config.find("options")
        for element in list(options.findall("listenAddress")):
            options.remove(element)
        ET.SubElement(options, "listenAddress").text = f'tcp://127.0.0.1:{peer["listen"]}'
        for name, value in {"globalAnnounceEnabled": "false", "localAnnounceEnabled": "false", "relaysEnabled": "false",
                            "natEnabled": "false", "urAccepted": "-1", "autoUpgradeIntervalH": "0", "crashReportingEnabled": "false"}.items():
            element = options.find(name)
            if element is None:
                element = ET.SubElement(options, name)
            element.text = value
        peer["tree"].write(peer["config"] / "config.xml")
    processes, logs = [], []
    try:
        for index, peer in enumerate(peers):
            log = (root / f"peer-{index}.log").open("w")
            logs.append(log)
            processes.append(subprocess.Popen([binary, "serve", "--home", str(peer["config"]), "--no-browser", "--no-restart", "--no-upgrade"],
                                              env=environment, stdout=log, stderr=subprocess.STDOUT))
        for peer in peers:
            wait_for(lambda: request(peer, "system/ping")["ping"] == "pong", processes, "REST API did not become ready")
        wait_for(lambda: all((peers[1]["folder"] / relative).is_file() for relative in allowed),
                 processes, "Allowed workspace documents were not synchronized")
        for relative in allowed:
            assert (peers[0]["folder"] / relative).read_bytes() == (peers[1]["folder"] / relative).read_bytes(), relative
        for relative in blocked:
            assert not (peers[1]["folder"] / relative).exists(), "Forbidden path synchronized: " + relative
        # Prove completion rather than checking only before a delayed transfer.
        wait_for(lambda: request(peers[0], "db/completion?folder=fixture&device=" + peers[1]["id"])["completion"] == 100,
                 processes, "Syncthing transfer did not reach completion")
        assert all(not (peers[1]["folder"] / relative).exists() for relative in blocked)
        print("Real Syncthing peers synchronized public docs/assets/configuration and excluded code, credentials, signing material and agent state.")
    finally:
        for process in processes:
            process.terminate()
        for process in processes:
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
        for log in logs:
            log.close()
