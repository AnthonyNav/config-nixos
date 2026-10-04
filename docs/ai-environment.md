# Fleet AI environment

The shared daily AI profile enables `fleet.ai.enable` for Desktop and Victus. It installs context and skills; it does not authenticate
assistants, enable paid services, change models or deploy anything. OpenCode
remains installed with user-owned configuration. Kiro Gateway is not restored.

## Sources and ownership

- `ai/context/{global,nixos}.md`: short shared instructions.
- `ai/default.nix`: host facts generated from evaluated inventory, plus adapters.
- `ai/skills/*/SKILL.md`: five canonical procedures, linked for each assistant.
- `ai/mcp/registry.nix`: known services, ownership, authentication and trust metadata.
- `ai/mcp/policy.nix`: explicit per-harness defaults and optional per-host overrides.
- `modules/home/ai-environment.nix`: Home Manager integration.
- `ai-doctor`: local diagnostics without network or authentication checks.

| Assistant | Context | Skills | RTK |
|---|---|---|---|
| Codex | Managed section of `~/.codex/AGENTS.md` | `~/.codex/skills/fleet-*` | Instruction fallback |
| Claude Code | `~/.claude/rules/nixos-fleet.md` | `~/.claude/skills/fleet-*` | Conservative PreToolUse hook |
| Kiro | `~/.kiro/steering/nixos-fleet.md` | `~/.kiro/skills/fleet-*` | Instruction fallback |

The Codex skill path matches the existing fleet installations. Current Codex
also supports `~/.agents/skills`; this change uses assistant-specific paths to
avoid implicitly adding custom OpenCode skills through a shared discovery root.
Kiro custom agents may omit global steering. The provided `nixos-fleet` agent
explicitly references the managed context and skills:
`kiro-cli chat --agent nixos-fleet`. It does not auto-trust tools or replace your
default agent.

Home Manager owns only the named rule, steering, agent and skill files.
Mutable settings remain user-owned. Activation reconciles a bounded managed
section in Codex AGENTS.md and one Claude hook group. When MCPs are enabled it
also reconciles only `fleet-*` entries selected by policy in Codex config.toml,
Claude's user MCP configuration (`~/.claude.json`) and Kiro's settings/mcp.json.
Other MCP entries, hooks, permissions, models and credentials are preserved.

Preflight rejects malformed settings, conflicting IDs, locally edited managed
sections, and symlinked mutable targets/ancestors. It validates all targets
before any integration write. Updates use atomic replacement with mode 0600.
A `.fleet-ai-backup` beside each changed mutable file retains the preceding
version; it can contain private settings and must remain local.
`~/.local/state/nixos-ai/ownership.json` records only previously managed entries
so updates, disabling and rollback can remove their own content. Never commit it.
There is no multi-file filesystem transaction: after an interrupted activation,
inspect backups and state before retrying if preflight reports a conflict.

To disable, set `fleet.ai.enable = false;` while retaining the module import.
Activation then removes its recorded sections/entries and Home Manager removes
its owned links. Do this before removing the module entirely. User-edited owned
sections must be reconciled explicitly rather than overwritten. Build validation
does not run these operations against the real home.

Nonstandard `CODEX_HOME`, `CLAUDE_CONFIG_DIR` or `KIRO_HOME` and Codex's
`AGENTS.override.md` can bypass these standard-path integrations. The doctor
reports these conditions. It does not silently relocate private settings.
Restart assistant sessions after deployment to reload context and hooks.

## RTK boundary

The pinned RTK provides `rewrite` and a Claude hook processor but no native
Codex/Kiro processor. The adapter uses `rtk rewrite` without executing the
requested command and accepts only these exact interactive summaries:
`git status`, `git diff`, `git diff --stat`, `git log -5` and
`git log --oneline -5`. It runs the pinned RTK binary when rewriting.

Shell composition, redirection, substitutions, mutation commands, already
wrapped commands and output intended for parsers pass through. Unsupported,
denied or failed rewrites also pass through; there is no execution retry.
The hook preserves other tool input fields and never emits an approval decision.
Claude's existing permission checks remain responsible for execution.
RTK is preferred through the shared instructions for other supported commands,
but that fallback is advisory, not automatic enforcement.

## MCP policy

The initial catalog contains the public OpenAI documentation service; all
managed enablement lists default to empty. A known service is not a connection.

For example, to enable it only for Codex on Desktop, change the policy to:

```nix
{
  defaults = { codex = [ ]; claude = [ ]; kiro = [ ]; };
  hosts.desktop.codex = [ "openai-docs" ];
}
```

Unspecified harnesses inherit defaults; an explicit empty list disables that
host/harness. Configuration generation rejects duplicate IDs, unknown selections,
unsupported harnesses, non-HTTPS URLs and authenticated entries selected without
a supported credential mechanism. The adapter supports credential-free HTTPS MCPs and store-backed local stdio
commands. Local process credentials are supplied at runtime, not in the registry. Authenticated integrations need a separate reviewed runtime
mechanism, such as sops-nix/agenix or a harness-native OAuth flow; never add
tokens, secret headers or .env contents to this catalog. Registry metadata must
not contain credential values. Existing user-managed MCPs are outside this policy.

## Validation and rollout

`checks.x86_64-linux.ai-environment` validates both generated host contexts,
skill frontmatter, MCP adapter JSON/TOML and rejection cases. Isolated-home tests
exercise preservation of personal settings, idempotence, dry-run, disabling,
collisions, malformed input and symlink refusal. Hook tests use the pinned RTK
without contacting a model or MCP.

Run formatting, flake evaluation/checks and all affected system/Home builds.
After reviewed main is activated, run `ai-doctor`, inspect context/skills in
each assistant, and verify a Claude summary command uses RTK while an exact
output command remains unchanged. Kiro agent parsing can be checked with
`kiro-cli agent validate --path ~/.kiro/agents/nixos-fleet.json` after runtime
login. The pinned CLI requires authentication even for this validation command;
build-time checks cover generated JSON and resource structure instead.
No build-time test proves that a model followed the instructions or that
external authentication succeeds.

## Optional Orca application

[Orca](orca.md) is packaged separately and enabled in the daily profile for Desktop and Victus
through `fleet.ai.orca.enable`. It uses the existing agent CLIs and leaves this
module's context, settings reconciliation and MCP policy unchanged. The option can be overridden in an explicit Home exception. Remote services are out of scope.

## Upstream references

- [Codex global instructions](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
- [Codex skills](https://learn.chatgpt.com/docs/build-skills) and [hooks](https://learn.chatgpt.com/docs/hooks)
- [Claude user rules](https://code.claude.com/docs/en/memory) and [hook protocol](https://code.claude.com/docs/en/hooks)
- [Kiro steering](https://kiro.dev/docs/steering/) and [agent configuration](https://kiro.dev/docs/custom-agents/configuration-reference/)
- [RTK hooks](https://github.com/rtk-ai/rtk/tree/develop/hooks) (verify supported processors against the pinned binary)

## Optional Android testing

[Artemis](artemis.md) is available through a separate opt-in launcher and per-host
`fleet.ai.artemis.harnesses` allowlist. Both installation and assistant connections
are off by default. It adds no global rules and is not required for the normal
AI or Spec Kit workflow.
