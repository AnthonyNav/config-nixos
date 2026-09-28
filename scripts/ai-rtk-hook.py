#!/usr/bin/env python3
"""Conservative Claude PreToolUse adapter. Never execute the requested command."""
import json
import shlex
import subprocess
import sys

# Only interactive summaries; avoid pipelines, substitutions, output parsers,
# mutations and commands whose flags alter their execution semantics.
SUPPORTED = {"git status", "git diff", "git diff --stat", "git log -5", "git log --oneline -5"}


def rewrite(payload, rtk):
    if not isinstance(payload, dict):
        return None
    if payload.get("tool_name") != "Bash":
        return None
    tool_input = payload.get("tool_input")
    if not isinstance(tool_input, dict):
        return None
    command = tool_input.get("command")
    if not isinstance(command, str) or command not in SUPPORTED:
        return None
    result = subprocess.run([rtk, "rewrite", command], capture_output=True, text=True, timeout=3)
    rewritten = result.stdout.strip()
    if result.returncode not in (0, 3) or rewritten != "rtk " + command:
        return None
    # Do not emit permissionDecision=allow: normal Claude approval still applies.
    return {"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "updatedInput": {**tool_input, "command": shlex.quote(rtk) + " " + command},
    }}


if __name__ == "__main__":
    try:
        output = rewrite(json.load(sys.stdin), sys.argv[1])
        if output:
            print(json.dumps(output))
    except (ValueError, TypeError, OSError, subprocess.TimeoutExpired):
        pass  # Unsupported/malformed input or unavailable RTK leaves the call untouched.
