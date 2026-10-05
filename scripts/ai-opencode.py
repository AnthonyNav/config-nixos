#!/usr/bin/env python3
"""Apply fleet config in a process-local overlay; never rewrite user JSON/JSONC."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import sys


def jsonc(raw):
    chars = list(raw)
    string, escape, index = False, False, 0
    while index < len(chars):
        char = chars[index]
        if string:
            if escape:
                escape = False
            elif char == "\\":
                escape = True
            elif char == '"':
                string = False
        elif char == '"':
            string = True
        elif char == "/" and index + 1 < len(chars) and chars[index + 1] in ("/", "*"):
            line = chars[index + 1] == "/"
            chars[index:index + 2] = [" ", " "]
            index += 2
            closed = line
            while index < len(chars):
                if line and chars[index] == "\n":
                    break
                if not line and chars[index:index + 2] == ["*", "/"]:
                    chars[index:index + 2] = [" ", " "]
                    index += 1
                    closed = True
                    break
                if chars[index] != "\n":
                    chars[index] = " "
                index += 1
            if not closed:
                raise ValueError("Unterminated JSONC comment")
        index += 1
    string, escape = False, False
    for index, char in enumerate(chars):
        if string:
            if escape:
                escape = False
            elif char == "\\":
                escape = True
            elif char == '"':
                string = False
        elif char == '"':
            string = True
        elif char == ",":
            following = index + 1
            while following < len(chars) and chars[following].isspace():
                following += 1
            if following < len(chars) and chars[following] in "}]":
                chars[index] = " "
    document = json.loads("".join(chars))
    if not isinstance(document, dict):
        raise ValueError("OpenCode configuration must be an object")
    return document


def project_directory(arguments):
    commands = {"completion", "acp", "mcp", "attach", "run", "debug", "providers", "auth", "agent", "upgrade", "uninstall", "serve", "web", "models", "stats", "export", "import", "github", "pr", "session", "plugin", "plug", "db"}
    values = {"--log-level", "--port", "--hostname", "--mdns-domain", "--model", "-m", "--session", "-s", "--prompt", "--agent", "--replay-limit"}
    index, selected = 0, None
    while index < len(arguments):
        argument = arguments[index]
        if argument == "--dir":
            if index + 1 >= len(arguments):
                raise ValueError("Missing OpenCode --dir argument")
            return Path(arguments[index + 1]).resolve()
        if argument.startswith("--dir="):
            return Path(argument.partition("=")[2]).resolve()
        if selected is None and not argument.startswith("-"):
            selected = argument
        if argument in values:
            index += 1
        index += 1
    return Path(selected).resolve() if selected and selected not in commands else Path.cwd()


def configuration_sources(home, env, cwd):
    sources = []
    config = Path(env.get("XDG_CONFIG_HOME", home / ".config")) / "opencode"
    roots = [config]
    if env.get("OPENCODE_CONFIG_DIR"):
        roots.append(Path(env["OPENCODE_CONFIG_DIR"]))
    for root in roots:
        sources.extend(root / name for name in ("opencode.json", "opencode.jsonc"))
    if env.get("OPENCODE_CONFIG"):
        sources.append(Path(env["OPENCODE_CONFIG"]))
    for root in (cwd, *cwd.parents):
        sources.extend(root / name for name in ("opencode.json", "opencode.jsonc"))
        sources.extend(root / ".opencode" / name for name in ("opencode.json", "opencode.jsonc"))
        if (root / ".git").exists():
            break
    return [path for path in dict.fromkeys(sources) if path.is_file()]


def overlay(bundle, config, env, arguments=()):
    spec = importlib.util.spec_from_file_location("workspace", Path(__file__).with_name("workspace-context.py"))
    workspace = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(workspace)
    directory = project_directory(arguments)
    info = workspace.resolve(config, git_prefix=["-C", str(directory)], directory=directory)
    context = info["context"]
    desired = json.loads((bundle / "opencode-overlay.json").read_text())
    registry = {"fleet-" + entry["id"]: entry for entry in json.loads((bundle / "registry.json").read_text())}
    # Each process gets its own selection. Other concurrent contexts stay intact.
    declared = desired["mcp"]
    desired["mcp"] = {name: value | {"enabled": registry[name]["context"] in ("any", context)} for name, value in declared.items()}
    current = jsonc(env.get("OPENCODE_CONFIG_CONTENT", "{}"))
    documents = [jsonc(path.read_text()) for path in configuration_sources(Path(config["homeDirectory"]), env, directory)]
    for document in [*documents, current]:
        servers = document.get("mcp", {})
        if not isinstance(servers, dict):
            raise ValueError("Invalid OpenCode MCP configuration")
        for name, value in declared.items():
            if name in servers and servers[name] != value:
                raise ValueError("Fleet MCP ID conflicts with user OpenCode configuration")
    instructions = current.get("instructions", [])
    if not isinstance(instructions, list) or not all(isinstance(item, str) for item in instructions):
        raise ValueError("Invalid OpenCode instructions")
    # Inline settings are merged last, so retain lower-precedence instructions too.
    for document in documents:
        values = document.get("instructions", [])
        if not isinstance(values, list) or not all(isinstance(item, str) for item in values):
            raise ValueError("Invalid OpenCode instructions")
        instructions.extend(item for item in values if item not in instructions)
    instructions.extend(item for item in desired["instructions"] if item not in instructions)
    if info["workspace"]:
        handoff = info["workspace"]["handoff"]
        if handoff not in instructions:
            instructions.append(handoff)
    current["instructions"] = instructions
    current["mcp"] = current.get("mcp", {}) | desired["mcp"]
    env = env.copy()
    env["OPENCODE_CONFIG_CONTENT"] = json.dumps(current)
    if env.get("FLEET_WRAPPER_BIN"):
        env["PATH"] = env["FLEET_WRAPPER_BIN"] + os.pathsep + env.get("PATH", "")
    return env


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--policy", type=Path, required=True)
    parser.add_argument("--binary", required=True)
    parser.add_argument("arguments", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    try:
        if args.arguments and args.arguments[0] == "upgrade":
            raise ValueError("Update the pinned OpenCode input through a reviewed fleet PR")
        environment = overlay(args.bundle, json.loads(args.policy.read_text()), os.environ.copy(), args.arguments)
        os.execvpe(args.binary, [args.binary, *args.arguments], environment)
    except (ValueError, OSError):
        print("fleet-opencode: configuration validation failed; user configuration was preserved.", file=sys.stderr)
        raise SystemExit(77)
