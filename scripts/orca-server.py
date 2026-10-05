#!/usr/bin/env python3
"""Read-only runtime evidence and explicit user-service helpers; never print auth state."""
import argparse
import getpass
import ipaddress
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from urllib.parse import urlsplit

UNIT = "orca-serve.service"
TAILNET = ipaddress.ip_network("100.64.0.0/10")


def run(args, timeout=4, env=None):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=timeout, env=env)
        return result.stdout if result.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired):
        return None


def object_from(raw):
    try:
        value = json.loads(raw or "null")
        return value if isinstance(value, dict) else {}
    except ValueError:
        return {}


def cli_environment(home):
    environment = os.environ | {"HOME": str(home), "XDG_CONFIG_HOME": str(home / ".config")}
    environment.pop("ORCA_USER_DATA_PATH", None)
    return environment


def endpoint(raw):
    try:
        value = urlsplit(raw or "")
        if value.scheme not in ("ws", "wss") or not value.hostname or not value.port:
            return None
        # Never expose credentials, query parameters or pairing paths.
        return {"address": value.hostname, "port": value.port,
                "url": f"{value.scheme}://{value.hostname}:{value.port}"}
    except (ValueError, TypeError):
        return None


def readiness(invocation):
    if not re.fullmatch(r"[a-fA-F0-9]{32}", invocation or ""):
        return {}
    raw = run(["journalctl", "--user", "-u", UNIT,
               f"_SYSTEMD_INVOCATION_ID={invocation}", "--no-pager", "-o", "cat",
               "--grep", "orca_server_ready", "-n", "1"])
    for line in (raw or "").splitlines():
        value = object_from(line)
        if value.get("type") == "orca_server_ready" and value.get("schemaVersion") == 1:
            return value
    return {}


def daemon_scopes(home, proc=Path("/proc")):
    """Match live daemon PID records to kernel identities and actual cgroups.

    Orca 1.4.220 does not publish main's optional readiness.health payload.
    Its PID records and /proc provide fresh evidence instead of trusting an old log.
    """
    runtime_directory = home / ".config/orca/daemon"
    scopes = []
    try:
        boot = (proc / "sys/kernel/random/boot_id").read_text().strip()
        records = list(runtime_directory.glob("daemon-v*.pid"))
        for path in records:
            record = object_from(path.read_text())
            pid = record.get("pid")
            if type(pid) is not int or pid <= 0:
                return {"verified": False, "units": []}
            process = proc / str(pid)
            if not process.exists():
                continue
            stat = (process / "stat").read_text().rsplit(")", 1)[1].split()
            command = (process / "cmdline").read_bytes().split(b"\0")
            if (process.stat().st_uid != os.getuid() or record.get("bootId") != boot
                    or record.get("linuxStartTicks") != stat[19]
                    or not any(b"daemon-entry" in arg for arg in command)
                    or str(path.with_suffix(".sock")).encode() not in command):
                return {"verified": False, "units": []}
            groups = (process / "cgroup").read_text()
            matches = re.findall(r"/(orca-daemon-[A-Za-z0-9:_.-]+\.scope)(?:\n|$)", groups)
            if len(matches) != 1:
                return {"verified": False, "units": []}
            scopes.append(matches[0])
        return {"verified": bool(scopes), "units": sorted(set(scopes))}
    except (OSError, ValueError, IndexError):
        return {"verified": False, "units": []}


def probe(policy, home, orca="orca-ide", username=None):
    mode = policy.get("mode", "off")
    data = {"mode": mode, "probed": False}
    if mode != "headless" or sys.platform != "linux":
        return data
    username = username or getpass.getuser()
    port = policy.get("port", 6768)
    data.update(probed=True, binaries={name: shutil.which(name) is not None
                                     for name in ("orca-ide", "Xvfb", "tailscale", "systemd-run")})
    raw = run(["systemctl", "--user", "show", UNIT, "--no-pager",
               "--property=LoadState,ActiveState,SubState,InvocationID"])
    service = dict(line.split("=", 1) for line in (raw or "").splitlines() if "=" in line)
    data["service"] = {key: service.get(key, "unknown") for key in ("LoadState", "ActiveState", "SubState")}
    data["linger"] = (run(["loginctl", "show-user", username, "--property=Linger", "--value"]) or "").strip() == "yes"
    vpn = object_from(run(["tailscale", "status", "--json"]))
    ip = (run(["tailscale", "ip", "-4"]) or "").strip()
    try:
        online = vpn.get("BackendState") == "Running" and vpn.get("Self", {}).get("Online") is True and ipaddress.ip_address(ip) in TAILNET
    except ValueError:
        online = False
    data["tailscale"] = {"online": online, "address": ip if online else None}
    ready = readiness(service.get("InvocationID"))
    bound = endpoint(ready.get("boundEndpoint"))
    advertised = endpoint(ready.get("advertisedEndpoint"))
    data["endpoint"] = advertised["url"] if advertised else None
    data["port_matches"] = bool(bound and advertised and bound["port"] == port and advertised["port"] == port)
    data["address_matches"] = bool(online and advertised and advertised["address"] == ip)
    data["pairing_available"] = ready.get("pairing", {}).get("available") is True
    status = object_from(run([orca, "status", "--json"], timeout=5, env=cli_environment(home))).get("result", {})
    runtime = status.get("runtime", {})
    app = status.get("app", {})
    data["runtime"] = {"reachable": runtime.get("reachable") is True,
                       "state": runtime.get("state", "unknown")}
    # A successful TCP connection alone could belong to a different application.
    listeners = run(["ss", "-H", "-ltnp", f"sport = :{port}"])
    pid = app.get("pid")
    data["listener_owned"] = type(pid) is int and f"pid={pid}," in (listeners or "")
    data["daemon_scope"] = daemon_scopes(home)
    data["healthy"] = (service.get("ActiveState") == "active" and data["linger"] and online
                       and all(data["binaries"].values())
                       and data["port_matches"] and data["address_matches"] and data["listener_owned"]
                       and runtime.get("reachable") is True and runtime.get("state") == "ready")
    return data


def empty_census(value):
    if value.get("ok") is not True:
        return False
    result = value.get("result", {})
    scope = result.get("hostScope", {})
    covered, omitted = scope.get("hostIds"), scope.get("omittedHostIds")
    # Paired runtimes have their own process boundary. Local/SSH or unknown
    # omissions cannot establish that stopping this runtime is safe.
    return (result.get("terminals") == [] and result.get("truncated") is False
            and isinstance(covered, list) and "local" in covered and isinstance(omitted, list)
            and all(isinstance(host, str) and host.startswith("runtime:") for host in omitted))


def redacted(line):
    value = object_from(line)
    if value.get("type") == "orca_server_ready":
        return json.dumps({"type": "orca_server_ready", "schemaVersion": value.get("schemaVersion"),
                           "boundEndpoint": endpoint(value.get("boundEndpoint")),
                           "advertisedEndpoint": endpoint(value.get("advertisedEndpoint")),
                           "pairingAvailable": value.get("pairing", {}).get("available") is True})
    if re.search(r"pairing|orca://pair|qr\s*[:=]|token|password|secret|authorization|credential|api[_-]?key", line, re.I):
        return "[Orca sensitive diagnostic omitted]"
    return re.sub(r"(https?://|wss?://)\S+", "[URL omitted]", line.rstrip())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("status", "logs", "restart"))
    parser.add_argument("--home", type=Path, default=Path.home())
    parser.add_argument("--port", type=int, default=6768)
    parser.add_argument("--orca", default="orca-ide")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--follow", action="store_true")
    parser.add_argument("--pairing", action="store_true", help="explicitly reveal the private pairing link; never share logs containing it")
    args = parser.parse_args()
    if args.action == "logs":
        if args.pairing:
            invocation = (run(["systemctl", "--user", "show", UNIT, "--property=InvocationID", "--value"]) or "").strip()
            pairing = readiness(invocation).get("pairing", {})
            if pairing.get("available") is not True or not isinstance(pairing.get("url"), str):
                print("No current pairing offer; check orca-server-status.", file=sys.stderr)
                return 1
            print(pairing["url"])
            return 0
        command = ["journalctl", "--user", "-u", UNIT, "--no-pager", "-o", "cat", "-n", "80"]
        if args.follow:
            command.append("--follow")
        with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True) as journal:
            try:
                for line in journal.stdout:
                    print(redacted(line), flush=True)
            except KeyboardInterrupt:
                journal.terminate()
            return journal.wait()
    data = probe({"mode": "headless", "port": args.port}, args.home, args.orca)
    if args.action == "status":
        print(json.dumps(data, indent=2) if args.json else
              f'Orca: {"ready" if data.get("healthy") else "not ready"}; service={data.get("service", {}).get("ActiveState", "unknown")}; '
              f'linger={data.get("linger")}; endpoint={data.get("endpoint") or "unavailable"}; '
              f'daemon scope verified={data.get("daemon_scope", {}).get("verified", False)}')
        return 0 if data.get("healthy") else 1
    state = data.get("service", {}).get("ActiveState")
    if state in ("active", "activating", "deactivating"):
        isolated = data.get("runtime", {}).get("reachable") and data.get("daemon_scope", {}).get("verified")
        if not isolated and not empty_census(object_from(run([args.orca, "terminal", "list", "--json"], timeout=5, env=cli_environment(args.home)))):
            print("Restart deferred: daemon isolation is unverified and the terminal census is active or incomplete. Preserve work before stopping the service.", file=sys.stderr)
            return 1
    elif state not in ("inactive", "failed"):
        print("Cannot verify user service state.", file=sys.stderr)
        return 1
    subprocess.run(["systemctl", "--user", "reset-failed", UNIT], check=True)
    return subprocess.run(["systemctl", "--user", "restart", UNIT]).returncode


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, subprocess.SubprocessError):
        print("Orca helper could not complete the operation; inspect redacted logs.", file=sys.stderr)
        raise SystemExit(1)
