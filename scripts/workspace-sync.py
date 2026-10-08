#!/usr/bin/env python3
"""Opt-in Git receivers. Local registration and receipts never enter Syncthing."""
import argparse
import contextlib
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time

from workspace import local_path, remote_url


def private_directory(home, relative):
    path = local_path(home / relative, home)
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    if not path.is_dir() or path.stat().st_uid != os.getuid():
        raise ValueError("Receiver state must belong to the current user")
    path.chmod(0o700)
    return path


def read_json(path, default):
    if path.is_symlink():
        raise ValueError("Receiver state must not be a symlink")
    if not path.exists():
        return default
    if not path.is_file() or path.stat().st_uid != os.getuid() or path.stat().st_mode & 0o077:
        raise ValueError("Receiver state must be a private regular file")
    return json.loads(path.read_text())


def write_json(path, value):
    if path.is_symlink():
        raise ValueError("Receiver state must not be a symlink")
    descriptor, temporary = tempfile.mkstemp(prefix=".workspace-sync-", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w") as stream:
            json.dump(value, stream, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


@contextlib.contextmanager
def lock(path, blocking=True):
    descriptor = os.open(path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        if os.fstat(descriptor).st_uid != os.getuid():
            raise ValueError("Receiver lock must belong to the current user")
        fcntl.flock(descriptor, fcntl.LOCK_EX | (0 if blocking else fcntl.LOCK_NB))
        yield
    finally:
        os.close(descriptor)


def registry(path):
    value = read_json(path, {"version": 1, "repositories": []})
    if (not isinstance(value, dict) or value.get("version") != 1
            or not isinstance(value.get("repositories"), list)):
        raise ValueError("Unsupported receiver registry")
    seen = set()
    for entry in value["repositories"]:
        if (not isinstance(entry, dict) or set(entry) != {"path", "common", "context", "remote", "url", "branch", "held"}
                or entry["context"] not in ("work", "personal") or type(entry["held"]) is not bool
                or any(not isinstance(entry[key], str) or not entry[key] for key in ("path", "common", "remote", "url", "branch"))
                or any(Path(entry[key]).is_absolute() or ".." in Path(entry[key]).parts for key in ("path", "common"))
                or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", entry["remote"])):
            raise ValueError("Malformed receiver registration")
        remote_url(entry["url"])
        if entry["path"] in seen:
            raise ValueError("Duplicate receiver registration")
        seen.add(entry["path"])
    return value


def environment(config, config_path, context, identity):
    env = identity.clean_environment(context, config)
    # Never inherit another checkout, identity override, askpass or Git config
    # from the shell invoking this command. Scope each repository separately.
    for key in list(env):
        if key.startswith("GIT_") or key in ("FLEET_CONTEXT_OVERRIDE", "SSH_ASKPASS", "SSH_ASKPASS_REQUIRE"):
            env.pop(key, None)
    env["HOME"] = config["homeDirectory"]
    env = identity.scoped_git_environment(config, config_path, context, env)
    env.update(GIT_TERMINAL_PROMPT="0", GIT_ASKPASS="", SSH_ASKPASS="", SSH_ASKPASS_REQUIRE="never",
               GIT_OPTIONAL_LOCKS="0", GIT_LFS_SKIP_SMUDGE="1")
    return env


def git(config, env, path, *arguments, timeout=15):
    return subprocess.run([config["binaries"]["git"], "-c", "core.hooksPath=/dev/null",
                           "-c", "core.fsmonitor=false", "-c", "merge.autoStash=false", "-C", str(path), *arguments],
                          env=env, capture_output=True, text=True, errors="replace", timeout=timeout)


def output(config, env, path, *arguments):
    result = git(config, env, path, *arguments)
    if result.returncode:
        # Git stderr may include credentials or remote-generated text.
        raise ValueError("Could not verify the registered Git checkout")
    return result.stdout.strip()


def context_for(config, path, identity, env):
    probe = env.copy()
    probe.pop("FLEET_CONTEXT_OVERRIDE", None)
    return identity.resolve(config, git_prefix=["-C", str(path)], directory=path, env=probe)


def inspect(config, home, path, remote, branch, context, identity, env):
    path = local_path(path, home)
    top = output(config, env, path, "rev-parse", "--show-toplevel")
    if Path(top).resolve() != path:
        raise ValueError("Register the checkout root")
    info = context_for(config, path, identity, env)
    if info["context"] not in ("neutral", context):
        raise ValueError("Receiver context conflicts with the repository's owning context")
    common = local_path(Path(info["git_common_dir"]), home)
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", remote):
        raise ValueError("Invalid remote name")
    if git(config, env, path, "check-ref-format", "refs/heads/" + branch).returncode:
        raise ValueError("Invalid receiving branch")
    url = output(config, env, path, "remote", "get-url", "--all", remote)
    remote_url(url)
    if not url:
        raise ValueError("The receiving remote must have exactly one URL")
    return {"path": str(path.relative_to(home)), "common": str(common.relative_to(home)),
            "context": context, "remote": remote, "url": url, "branch": branch, "held": False}


def checkout_state(config, home, entry, identity, env):
    path = local_path(home / entry["path"], home)
    actual = inspect(config, home, path, entry["remote"], entry["branch"], entry["context"], identity, env)
    if any(actual[key] != entry[key] for key in ("path", "common", "context", "remote", "url", "branch")):
        return "registration-changed", None
    current = git(config, env, path, "symbolic-ref", "--quiet", "--short", "HEAD")
    if current.returncode or current.stdout.strip() != entry["branch"]:
        return "branch-changed", None
    gitdir = Path(output(config, env, path, "rev-parse", "--absolute-git-dir"))
    markers = ("index.lock", "HEAD.lock", "packed-refs.lock", "config.lock", "shallow.lock", "MERGE_HEAD",
               "REBASE_HEAD", "CHERRY_PICK_HEAD", "REVERT_HEAD", "BISECT_LOG", "sequencer", "rebase-apply", "rebase-merge")
    for root in (gitdir, home / entry["common"]):
        if any((root / marker).exists() for marker in (*markers, "refs/heads/" + entry["branch"] + ".lock")):
            return "git-operation", None
    if output(config, env, path, "status", "--porcelain=v1", "--untracked-files=all"):
        return "dirty", None
    if output(config, env, path, "ls-files", ".gitmodules"):
        return "submodules", None
    return None, output(config, env, path, "rev-parse", "HEAD")


def activity(config, path):
    """Conservative process-CWD guard, supplemented by the explicit hold command.

    Editors can retain unsaved buffers without a CWD/file descriptor in the
    checkout. Registration is for receiving copies; hold before editing them.
    """
    result = subprocess.run([config["binaries"]["lsof"], "-n", "-P", "-a", "-u", str(os.getuid()),
                             "-d", "cwd", "-Fpcn0"], capture_output=True, timeout=15)
    if result.returncode or not result.stdout:
        return "activity-unverified"
    pid = None
    for field in result.stdout.split(b"\0"):
        field = field.lstrip(b"\n")
        if field.startswith(b"p"):
            try:
                pid = int(field[1:])
            except ValueError:
                return "activity-unverified"
        elif field.startswith(b"n") and pid != os.getpid():
            cwd = Path(os.fsdecode(field[1:])).resolve()
            if cwd == path or path in cwd.parents:
                return "busy"
    return None


def receive(config, config_path, home, entry, identity, registry_path, registry_lock):
    receipt = {key: entry[key] for key in ("path", "context", "remote", "branch")}
    receipt["checked_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    if entry["held"]:
        return receipt | {"result": "held"}
    env = environment(config, config_path, entry["context"], identity)
    path = home / entry["path"]
    reason, before = checkout_state(config, home, entry, identity, env)
    if reason:
        return receipt | {"result": reason}
    receipt["before"] = before
    ref = "refs/fleet/workspace-sync/" + hashlib.sha256(entry["path"].encode()).hexdigest()[:24]
    fetched = git(config, env, path, "fetch", "--quiet", "--no-tags", "--no-recurse-submodules",
                  "--no-write-fetch-head", "--", entry["url"], f"+refs/heads/{entry['branch']}:{ref}", timeout=60)
    if fetched.returncode:
        return receipt | {"result": "fetch-unavailable"}
    target = output(config, env, path, "rev-parse", ref + "^{commit}")
    receipt["fetched"] = target
    if target == before:
        return receipt | {"result": "current", "after": before}
    if git(config, env, path, "merge-base", "--is-ancestor", before, target).returncode:
        ahead = git(config, env, path, "merge-base", "--is-ancestor", target, before).returncode == 0
        return receipt | {"result": "ahead" if ahead else "diverged"}
    # Registration/hold changes during a fetch win over that background run.
    # Recheck the checkout and activity immediately before a short FF mutation.
    with lock(registry_lock):
        current = next((item for item in registry(registry_path)["repositories"] if item["path"] == entry["path"]), None)
        if current != entry:
            return receipt | {"result": "registration-changed"}
        reason, head = checkout_state(config, home, entry, identity, env)
        if reason or head != before:
            return receipt | {"result": reason or "checkout-changed"}
        reason = activity(config, path)
        if reason:
            return receipt | {"result": reason}
        merged = git(config, env, path, "merge", "--ff-only", "--no-edit", "--no-stat", "--no-overwrite-ignore", target)
        if merged.returncode:
            return receipt | {"result": "apply-blocked"}
        return receipt | {"result": "updated", "after": output(config, env, path, "rev-parse", "HEAD")}


def main(config, config_path, arguments, identity):
    parser = argparse.ArgumentParser(description=__doc__)
    actions = parser.add_subparsers(dest="action", required=True)
    register = actions.add_parser("register", help="opt a receiving checkout into clean fast-forward updates")
    register.add_argument("path", type=Path)
    register.add_argument("--context", choices=("work", "personal"))
    register.add_argument("--remote", default="origin")
    register.add_argument("--branch", help="defaults to the currently checked-out branch")
    for action in ("unregister", "hold", "resume"):
        actions.add_parser(action).add_argument("path", type=Path)
    for action in ("run", "status"):
        actions.add_parser(action).add_argument("--json", action="store_true")
    args = parser.parse_args(arguments)
    home = Path(config["homeDirectory"]).resolve()
    registry_path = local_path(home / ".config/fleet/workspace-sync.json", home)
    if args.action == "status":
        entries = registry(registry_path)["repositories"]
        receipts = read_json(local_path(home / ".local/state/fleet/workspace-sync/receipts.json", home), [])
        data = {"repositories": [{key: item[key] for key in ("path", "context", "remote", "branch", "held")} for item in entries], "receipts": receipts}
        print(json.dumps(data, indent=2) if args.json else "\n".join(
            f"{item['path']}: {next((r['result'] for r in receipts if r['path'] == item['path']), 'not-run')}; branch={item['branch']}; held={item['held']}"
            for item in data["repositories"]) or "No registered receiving checkouts.")
        return 0
    config_dir = private_directory(home, ".config/fleet")
    state_dir = private_directory(home, ".local/state/fleet/workspace-sync")
    registry_lock = config_dir / "workspace-sync.lock"
    if args.action == "run":
        try:
            with lock(state_dir / "run.lock", blocking=False):
                with lock(registry_lock):
                    entries = registry(registry_path)["repositories"]
                receipts = []
                for entry in entries:
                    try:
                        result = receive(config, config_path, home, entry, identity, registry_path, registry_lock)
                    except (ValueError, OSError, subprocess.TimeoutExpired):
                        result = {key: entry[key] for key in ("path", "context", "remote", "branch")}
                        result.update(result="verification-unavailable", checked_at=time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()))
                    receipts.append(result)
                    write_json(state_dir / "receipts.json", receipts)
                write_json(state_dir / "receipts.json", receipts)
        except BlockingIOError:
            receipts = [{"result": "receiver-running"}]
        print(json.dumps(receipts) if args.json else "\n".join(f"{item.get('path', 'receiver')}: {item['result']}" for item in receipts) or "No registered receiving checkouts.")
        return 0
    path = local_path(args.path.expanduser().absolute(), home)
    relative = str(path.relative_to(home))
    with lock(registry_lock):
        value = registry(registry_path)
        previous = next((item for item in value["repositories"] if item["path"] == relative), None)
        if args.action == "register":
            if previous:
                raise ValueError("Checkout already registered; unregister it before changing its receiving policy")
            env = environment(config, config_path, "neutral", identity)
            info = context_for(config, path, identity, env)
            context = args.context or info["context"]
            if context not in ("work", "personal"):
                raise ValueError("A neutral checkout requires an explicit --context")
            branch = args.branch or output(config, env, path, "symbolic-ref", "--quiet", "--short", "HEAD")
            if output(config, env, path, "symbolic-ref", "--quiet", "--short", "HEAD") != branch:
                raise ValueError("Check out the receiving branch before registration")
            entry = inspect(config, home, path, args.remote, branch, context, identity, env)
            value["repositories"].append(entry)
        else:
            if not previous:
                raise ValueError("Checkout is not registered")
            if args.action == "unregister":
                value["repositories"].remove(previous)
            else:
                previous["held"] = args.action == "hold"
        write_json(registry_path, value)
    print(f"{args.action}: {relative}")
    return 0
