#!/usr/bin/env python3
import json
from pathlib import Path
import sys
import tomllib
import yaml

fixtures = json.loads(Path(sys.argv[1]).read_text())
for host, location in fixtures["hosts"].items():
    bundle = Path(location)
    facts = json.loads((bundle / "host.json").read_text())
    inventory = fixtures["inventory"][host]
    assert facts["host"] == host
    assert facts["platform"] == inventory["system"]
    assert facts["kind"] == inventory["kind"]
    assert facts["role"] == inventory["role"]
    assert facts["graphics"] == inventory["features"]["graphics"]
    for name, value in inventory["capabilities"].items():
        assert facts["capabilities"][name] == value
    context = (bundle / "context.md").read_text()
    assert f"Host: {host}" in context
    assert len(context.encode()) < 8192
    names = []
    for path in (bundle / "skills").glob("*/SKILL.md"):
        text = path.read_text()
        assert text.startswith("---\n")
        metadata = yaml.safe_load(text.split("---", 2)[1])
        assert metadata["name"] == path.parent.name
        assert isinstance(metadata["description"], str) and metadata["description"]
        names.append(metadata["name"])
    assert len(names) == 6 and len(set(names)) == len(names)
    manifest = json.loads((bundle / "manifest.json").read_text())
    assert manifest["text"][".codex/AGENTS.md"] == context
    assert all(not values for values in json.loads((bundle / "enabled.json").read_text()).values())
    agent = json.loads((bundle / "kiro-agent.json").read_text())
    assert agent["allowedTools"] == []
    assert agent["mcpServers"] == {}
    assert not any("opencode" in path for path in json.loads((bundle / "files.json").read_text()))
    assert not any("opencode" in path for kind in manifest.values() for path in kind)
    assert any(path.startswith(".agents/skills/") for path in json.loads((bundle / "files.json").read_text()))
    overlay = json.loads((bundle / "opencode-overlay.json").read_text())
    assert overlay["mcp"] == {} and len(overlay["instructions"]) == 1

enabled = Path(fixtures["enabled"])
manifest = json.loads((enabled / "manifest.json").read_text())
codex = tomllib.loads(manifest["text"][".codex/config.toml"])
assert codex["mcp_servers"]["fleet-openai-docs"]["url"] == "https://developers.openai.com/mcp"
for target in (".claude.json", ".kiro/settings/mcp.json"):
    entry = manifest["json"][target][0]
    assert entry["path"] == ["mcpServers", "fleet-openai-docs"]
    assert entry["value"]["url"] == "https://developers.openai.com/mcp"
print("All host contexts, skills and MCP adapters validated.")

local = Path(fixtures["localEnabled"])
manifest = json.loads((local / "manifest.json").read_text())
connection = tomllib.loads(manifest["text"][".codex/config.toml"])["mcp_servers"]["fleet-artemis"]
assert connection["command"].startswith("/nix/store/")
assert connection["args"] == [] and "url" not in connection
for target in (".claude.json", ".kiro/settings/mcp.json"):
    entry = next(e for e in manifest["json"][target] if e["path"][-1] == "fleet-artemis")
    assert entry["value"]["command"] == connection["command"]
    assert entry["value"]["args"] == []
    assert "env" not in entry["value"] and "url" not in entry["value"]
    if target == ".claude.json":
        assert entry["value"]["type"] == "stdio"
agent = json.loads((local / "kiro-agent.json").read_text())
assert agent["allowedTools"] == []
assert agent["mcpServers"]["fleet-artemis"] == connection
print("Opt-in stdio adapters validated without auto-approving tools.")

guarded = Path(fixtures["guardedEnabled"])
manifest = json.loads((guarded / "manifest.json").read_text())
entry = tomllib.loads(manifest["text"][".codex/config.toml"])["mcp_servers"]["fleet-work-fixture"]
assert entry["command"].startswith("/nix/store/") and entry["args"] == []
assert "TEST_TOKEN" not in json.dumps(manifest)
overlay = json.loads((guarded / "opencode-overlay.json").read_text())
assert overlay["mcp"]["fleet-work-fixture"]["command"] == [entry["command"]]
assert overlay["mcp"]["fleet-work-fixture"]["type"] == "local"
print("Restricted adapters gate startup; secret values stay outside all manifests.")
