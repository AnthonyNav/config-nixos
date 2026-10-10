#!/usr/bin/env python3
"""Run the Hammerspoon contract with a mocked hs API; never open native UI."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile


def lua_literal(value):
    if isinstance(value, str):
        return '"' + "".join(f"\\{byte:03d}" for byte in value.encode()) + '"'
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if value is None:
        return "nil"
    if isinstance(value, list):
        return "{" + ",".join(map(lua_literal, value)) + "}"
    if isinstance(value, dict):
        return "{" + ",".join(
            f"[{lua_literal(key)}]={lua_literal(item)}" for key, item in value.items()
        ) + "}"
    raise TypeError(type(value))


def main():
    if len(sys.argv) not in (3, 4):
        raise SystemExit("usage: check-fleet-darwin.py SOURCE_ROOT LUA_BINARY [CATALOG_PATH]")
    root = Path(sys.argv[1]).resolve()
    catalog_path = Path(sys.argv[3]) if len(sys.argv) == 4 else root / "dotfiles/fleet/actions.json"
    catalog = json.loads(catalog_path.read_text())
    with tempfile.TemporaryDirectory(prefix="fleet-lua-contract-") as temporary:
        fixture = Path(temporary) / "catalog.lua"
        fixture.write_text("return " + lua_literal(catalog) + "\n")
        subprocess.run([
            sys.argv[2], str(root / "scripts/tests/check-fleet-darwin.lua"),
            str(root / "dotfiles/hammerspoon/fleet.lua"), str(fixture),
        ], check=True)


if __name__ == "__main__":
    main()
