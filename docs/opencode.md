# OpenCode Workflow

## Managed Tools

Every workstation receives these files through Home Manager:

- `opencode/plugins/rtk.js`: rewrites supported shell commands through RTK to
  keep command output compact before it reaches an agent.
- `opencode/skills/graphify`: builds or queries a persistent repository graph.
- `opencode/skills/pre-pr-review`: reviews pending changes against the real
  configuration and validation flow.
- `opencode/skills/nixos-maintenance`: applies this repository's NixOS change
  and validation rules.
- `opencode/skills/network-diagnostics`: follows the ThinkPad Wi-Fi protocol.

Restart OpenCode after changing a skill or plugin. OpenCode discovers the
managed files under `~/.config/opencode/` automatically.

## Local Configuration And Secrets

`opencode/opencode.json` is the Nix-managed provider configuration. Its Kiro
key is the `{env:PROXY_API_KEY}` runtime placeholder, resolved by the managed
`opencode` wrapper from the gateway's private `.env`. Do not add tokens, OAuth
data, or database passwords to Git.

The managed plugin and skills work without changing the local Kiro config.
Edit the repository configuration, retain its `$schema`, and validate JSON
before applying Home Manager:

```sh
jq empty opencode/opencode.json
```

Kiro Gateway discovers the models available to the signed-in account from
Kiro's control-plane API. OpenCode custom providers still require an explicit
`models` map, so the `kiro-opencode-model-sync` user timer writes newly
detected IDs to `~/.local/state/opencode/kiro-models.json` every hour. OpenCode
merges that catalog after the Nix-managed base configuration. The gateway alias
`auto-kiro` is excluded: use the actual Kiro model ID `auto`. Run
`kgw-models-sync` to refresh it now, then restart OpenCode.

When Kiro advertises native reasoning levels for a model, the sync also creates
matching OpenCode variants. Select `high` or `max` from `/models`; the gateway
forwards the model-specific native Kiro field rather than using its fake
reasoning fallback. The current GPT Luna, Sol, and Terra models support
`low`, `medium`, `high`, `xhigh`, and `max`.

## Optional MCP Servers

MCP servers are intentionally not enabled globally. They add tool schemas and
context to every session, and some can access private data or perform writes.
Enable them in the local config or a project config only when their capability
is needed.

### GitHub

The official GitHub MCP can inspect repositories, issues, pull requests, and
Actions. Start with a minimally scoped local token and read-only work. Put the
token in the environment, never in the JSON or repository:

```json
{
  "mcp": {
    "github": {
      "type": "remote",
      "url": "https://api.githubcopilot.com/mcp/",
      "enabled": true,
      "headers": {
        "Authorization": "Bearer {env:GITHUB_PAT}"
      },
      "timeout": 30000
    }
  }
}
```

### Context7

Context7 retrieves current, version-specific library documentation. Prefer its
CLI plus skill workflow for routine coding because it avoids loading MCP tools
in every session. Its remote MCP is useful only for documentation-heavy work:

```json
{
  "mcp": {
    "context7": {
      "type": "remote",
      "url": "https://mcp.context7.com/mcp",
      "enabled": true,
      "headers": {
        "Authorization": "Bearer {env:CONTEXT7_API_KEY}"
      },
      "timeout": 30000
    }
  }
}
```

### Browser Automation

Use Playwright CLI plus a project skill for routine frontend work. Its upstream
project recommends this path for coding agents because it is more token
efficient than a global MCP. Configure Playwright MCP only for exploratory,
stateful browser sessions, and limit it to the project that needs it.

## Context Control

RTK is the default token-saving mechanism. For a local config that needs
tighter limits, add these schema-supported fields without replacing the Kiro
provider block:

```json
{
  "tool_output": {
    "max_lines": 200,
    "max_bytes": 8192
  },
  "compaction": {
    "auto": true,
    "prune": true,
    "tail_turns": 6
  }
}
```
