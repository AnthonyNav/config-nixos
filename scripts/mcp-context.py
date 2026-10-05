#!/usr/bin/env python3
"""Gate MCP startup by workspace before reading any context-owned credentials."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import stat
import sys


def workspace_module():
    spec = importlib.util.spec_from_file_location("workspace", Path(__file__).with_name("workspace-context.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def credentials(entry, config, context):
    required = entry["requiredSecrets"]
    authentication = entry["authentication"]
    if authentication in ("none", "oauth"):
        return {}
    if context not in ("work", "personal"):
        raise PermissionError("MCP credentials require work or personal context")
    if authentication == "runtime-env":
        # Prefixed names cannot accidentally consume a token from the other context.
        prefix = f"FLEET_MCP_{context.upper()}_{entry['id'].upper().replace('-', '_')}_"
        values = {name: os.environ.get(prefix + name) for name in required}
    else:
        home = Path(config["homeDirectory"])
        path = home / ".config/fleet/secrets" / context / "mcp" / (entry["id"] + ".json")
        if path.is_symlink() or any(parent.is_symlink() for parent in path.parents):
            raise PermissionError("MCP secret path must not traverse symlinks")
        # O_NOFOLLOW protects the final component against concurrent replacement.
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
        with os.fdopen(fd) as stream:
            metadata = os.fstat(stream.fileno())
            if not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != os.getuid() or metadata.st_mode & 0o077:
                raise PermissionError("MCP secret file must be user-owned and mode 0600")
            document = json.load(stream)
        if not isinstance(document, dict) or set(document) != set(required):
            raise ValueError("MCP secret names do not match the declared contract")
        values = {name: document[name] for name in required}
    if any(not isinstance(value, str) or not value for value in values.values()):
        raise ValueError("Missing MCP runtime credentials")
    return values


def launch(entry, config, proxy):
    workspace = workspace_module()
    context = workspace.resolve(config)["context"]
    if entry["context"] not in ("any", context):
        raise PermissionError("MCP is unavailable in the current workspace context")
    values = credentials(entry, config, context)
    env = workspace.clean_environment(context, config)
    # Only this server's declared credentials survive into its process.
    for name in list(env):
        if name.startswith("FLEET_MCP_") or name in entry["requiredSecrets"] or name == "API_ACCESS_TOKEN":
            env.pop(name)
    env.update(values)
    if entry["transport"] == "stdio":
        command = [entry["command"], *entry["args"]]
    else:
        if entry["authentication"] == "oauth":
            raise ValueError("Restricted HTTP OAuth requires a supported native adapter")
        if not proxy:
            raise ValueError("HTTP MCP requires the pinned transport bridge")
        # Remote-client mode only: no listening port or daemon is created.
        command = [proxy, "--transport", "streamablehttp", "--log-level", "ERROR", entry["url"]]
    os.execvpe(command[0], command, env)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--policy", type=Path, required=True)
    parser.add_argument("--entry", type=Path, required=True)
    parser.add_argument("--proxy")
    options = parser.parse_args()
    try:
        launch(json.loads(options.entry.read_text()), json.loads(options.policy.read_text()), options.proxy)
    except (ValueError, OSError) as error:
        # JSON parser documents and OS errors may contain private paths/values.
        print(f"fleet-mcp: {type(error).__name__}; context or runtime credential validation failed.", file=sys.stderr)
        raise SystemExit(77)
