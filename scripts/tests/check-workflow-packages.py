#!/usr/bin/env python3
"""Headless integration of the built packages, wrappers and a local Hurl fixture."""
import ast
import asyncio
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import shlex
import site
import subprocess
import sys
import tempfile
import threading

packages = json.loads(Path(sys.argv[1]).read_text())
hurl_example = str(Path(sys.argv[2]).resolve())


def run(*args, env):
    result = subprocess.run(args, env=env, capture_output=True, text=True, timeout=30)
    assert result.returncode == 0, result.stderr
    return result.stdout


with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    env = os.environ.copy()
    for name in ("DISPLAY", "WAYLAND_DISPLAY", "POSTING_CONFIG_FILE", "POSTING_HISTORY__ENABLED", "ORCA_CLI_COMMAND"):
        env.pop(name, None)
    env.update(HOME=str(root), XDG_CONFIG_HOME=str(root / "config"), XDG_CACHE_HOME=str(root / "cache"), XDG_DATA_HOME=str(root / "data"), XDG_STATE_HOME=str(root / "state"))
    fake = root / "capture"
    fake.write_text(f'#!{sys.executable}\nimport json, os, sys\nprint(json.dumps({{"args":sys.argv[1:], "schema":os.getenv("GSETTINGS_SCHEMA_DIR"), "wayland":os.getenv("NIXOS_OZONE_WL"), "history":os.getenv("POSTING_HISTORY__ENABLED")}}))\n')
    fake.chmod(0o700)

    def exercise_wrapper(path):
        raw = path.read_text()
        # Replace only the final exec target in a COPY of the built wrapper.
        match = re.search(r'(exec -a "\$0" )("[^"]+"|[^\s]+)', raw)
        assert match, f"Unexpected wrapper format: {path}"
        adjusted = raw[:match.start(2)] + shlex.quote(str(fake)) + raw[match.end(2):]
        copy = root / path.name
        copy.write_text(adjusted)
        copy.chmod(0o700)
        return json.loads(run(str(copy), "literal $(value); argument", env=env | {"NIXOS_OZONE_WL": "1"}))

    postman = Path(packages["postman"])
    value = exercise_wrapper(postman / "bin/postman")
    assert value["schema"] == packages["schemas"] and value["wayland"] is None
    assert value["args"] == ["literal $(value); argument"]
    desktop = (postman / "share/applications/postman.desktop").read_text()
    assert f'Exec={postman}/bin/postman %U' in desktop
    schemas = run("gsettings", "list-schemas", env=env | {"GSETTINGS_SCHEMA_DIR": packages["schemas"]})
    assert "org.gtk.Settings.FileChooser" in schemas

    posting = Path(packages["posting"])
    value = exercise_wrapper(posting / "bin/posting")
    assert value["history"] == "false" and value["args"] == ["literal $(value); argument"]
    run(str(posting / "bin/posting"), "--help", env=env)
    # Use the package's actual propagated Python dependencies, not the host's.
    python_entry = next(path for path in (posting / "bin").glob(".posting-wrapped*") if "site.addsitedir" in path.read_text())
    match = re.search(r'site.addsitedir\(p, k\), (\[.*?\]), site\._init_pathinfo', python_entry.read_text())
    assert match
    for directory in ast.literal_eval(match.group(1)):
        site.addsitedir(directory)
    os.environ.update(env | {"POSTING_HISTORY__ENABLED": "false"})
    from posting.__main__ import make_posting
    from posting.config import Settings
    assert Settings().history.enabled is False
    collection = root / "collection"
    collection.mkdir()

    async def boot_posting():
        app = make_posting(collection, using_default_collection=False)
        async with app.run_test(size=(120, 40)) as pilot:
            await pilot.pause()
            assert app.settings.history.enabled is False
    asyncio.run(boot_posting())

    class Health(BaseHTTPRequestHandler):
        def do_GET(self):
            body = b'{"status":"ok"}'
            self.send_response(200 if self.path == "/health" else 404)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *_):
            pass

    server = ThreadingHTTPServer(("127.0.0.1", 0), Health)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        run(packages["hurl"], "--test", "--variable", f"base_url=http://127.0.0.1:{server.server_port}", hurl_example, env=env)
    finally:
        server.shutdown()
        server.server_close()
        thread.join()

    orca = Path(packages["orca"])
    assert run(str(orca / "bin/orca-ide"), "--version", env=env).strip() == "1.4.220"
    result = json.loads(run(str(orca / "bin/orca-ide"), "skills", "install", "--skill", "orca-cli", "--agent", "universal", "--dry-run", "--json", env=env))
    assert result["executed"] is False and result["skills"] == ["orca-cli"]
    remote = Path(packages["orcaNative"]) / "app/resources/orcad-template/targets"
    for name in ("linux-x64-musl", "linux-x64-glibc", "linux-arm64-musl", "linux-arm64-glibc"):
        assert (remote / name).is_dir()
        for path in (remote / name).rglob("*.node"):
            assert b"/nix/store/" not in path.read_bytes(), f"Remote module was rewritten for local Nix: {path}"

print("Postman schemas/argv, Posting history/headless UI, local Hurl API, Orca CLI/skills and portable remote modules validated.")
