# Fleet AI environment

The shared daily profile enables `fleet.ai.enable` for Desktop and Victus.
It installs fleet context and skills without authenticating assistants, changing
models or deploying anything. OpenCode's providers, models, permissions, plugins
and credentials remain user-owned; a launcher adds the bounded fleet overlay.
Kiro Gateway is not restored. See [workspace-workflow.md](workspace-workflow.md)
for identity, synchronization and migration.

## Sources and ownership

- `ai/context/{global,nixos}.md`: short shared instructions.
- `ai/default.nix`: evaluated host facts and four harness adapters.
- `ai/skills/*/SKILL.md`: six canonical fleet procedures.
- `ai/mcp/registry.nix`: catalog with ownership/trust/context/auth metadata.
- `ai/mcp/policy.nix`: explicit per-harness defaults and per-host selections.
- `modules/home/ai-environment.nix`: Home Manager integration.
- `ai-doctor`: local diagnostics without network/login checks.

| Assistant | Context | Skills | RTK |
|---|---|---|---|
| Codex | Managed section of `~/.codex/AGENTS.md` | `~/.codex/skills/fleet-*` and universal root | Instruction fallback |
| Claude Code | `~/.claude/rules/nixos-fleet.md` | `~/.claude/skills/fleet-*` and universal root | Conservative PreToolUse hook |
| Kiro | `~/.kiro/steering/nixos-fleet.md` | `~/.kiro/skills/fleet-*` and universal root | Instruction fallback |
| OpenCode | Process-local instructions overlay | `~/.agents/skills/fleet-*` | Instruction fallback |

Universal discovery is `~/.agents/skills`, also visible to Orca-discovered Agent
Skills. Home Manager owns the named fleet links, not the whole directory.
Orca's mutable upstream stubs are managed explicitly with `orca-skills-sync`;
they are never installed/updated by activation. `fleet-orca-workspaces` is the
sixth canonical skill.

Kiro custom agents may omit global steering. `kiro-cli chat --agent nixos-fleet`
explicitly references fleet context/skills without changing the default agent
or trusting tools automatically.

Activation reconciles a bounded Codex AGENTS section, one Claude hook group,
and only recorded `fleet-*` MCP entries in Codex config.toml, Claude's
`~/.claude.json` and Kiro settings/mcp.json. Other entries, hooks, permissions,
models and credentials are preserved. Preflight validates all targets, rejects
malformed settings, conflicting IDs/owned edits and symlinked targets/ancestors
before integration writes. Atomic replacements are mode 0600.

A private `.fleet-ai-backup` beside each changed file retains its preceding
version. `~/.local/state/nixos-ai/ownership.json` records only fleet ownership;
never commit either. Ordinary mid-write failures compensate completed writes
when no concurrent user edit occurred. This is not a filesystem transaction:
SIGKILL/power loss requires inspecting state/backups before retrying conflicts.

To disable, set `fleet.ai.enable = false;` while retaining the module import.
Activation removes recorded entries and Home Manager removes its links. Do this
before removing the module entirely. User-edited owned content requires explicit
reconciliation. Build tests never operate on the real user home.

Nonstandard `CODEX_HOME`, `CLAUDE_CONFIG_DIR`, `KIRO_HOME` and Codex
`AGENTS.override.md` may bypass standard-path integration; the doctor reports
these conditions without moving private settings. Restart sessions after
deployment.

## OpenCode process overlay

The pinned launcher reads existing JSON/JSONC without rewriting files and adds
fleet instructions/MCPs through `OPENCODE_CONFIG_CONTENT`. Existing inline
settings, providers, models, permissions, instructions and unrelated user MCPs
are retained. Global, project and explicitly selected configuration paths are
checked for conflicting reserved fleet IDs. Invalid/colliding configuration
fails before OpenCode starts. No persistent OpenCode ownership manifest or
configuration replacement is created.

Project positional arguments and `run --dir` select the same canonical context
as Git. Wrong-context fleet MCPs receive `enabled = false` and restricted
connections are checked again at startup. Start a new process to switch account
scope. The wrapper refuses `opencode upgrade`; update the Nix input through a
reviewed PR. OpenCode still owns native login/provider state.

## RTK boundary

The pinned RTK has `rewrite` and a Claude hook processor. The fleet hook accepts
only exact interactive summaries: `git status`, `git diff`, `git diff --stat`,
`git log -5` and `git log --oneline -5`. It rewrites without executing the
requested command. Shell composition, substitutions, redirection, mutations,
already wrapped commands and exact output pass through. Unsupported/failed
rewrites also pass through without execution retry or approval decisions.
Claude's native permissions remain responsible for execution. Other harnesses
receive advisory RTK instructions.

## MCP policy and secrets

All four default enablement lists are empty. Cataloged means known, not enabled.
For example, enable public documentation only for Codex on Desktop:

```nix
{
  defaults = { codex = [ ]; claude = [ ]; kiro = [ ]; opencode = [ ]; };
  hosts.desktop.codex = [ "openai-docs" ];
}
```

Unspecified harnesses inherit defaults; an explicit empty list disables that
host/harness. Duplicate IDs/selections, unsupported consumers, non-HTTPS URLs,
unknown fields and unsupported authentication selections fail evaluation.

Each entry declares `context = "any" | "work" | "personal"`,
`authentication = "none" | "oauth" | "runtime-env" | "runtime-file"` and a unique
`requiredSecrets` list of uppercase environment variable names. No `env`,
token value or secret header belongs in the registry. STDIO executables must
be Nix-store paths. Runtime credentials require a restricted context and a
nonempty secret list. `none`/`oauth` require an empty secret list.

Every STDIO connection and restricted/runtime HTTP connection uses the common
workspace resolver before reading secrets. Wrong context refuses startup.
Incoming GitHub/AWS credentials and other fleet-MCP token variables are removed;
only this entry's declared runtime credentials are forwarded. This scopes
managed launches; arbitrary same-user programs can still read local files.

- `runtime-env`: export a secret externally as
  `FLEET_MCP_WORK_EXAMPLE_API_API_ACCESS_TOKEN` for a work entry
  `id = "example-api"`, `requiredSecrets = [ "API_ACCESS_TOKEN" ];`.
  Personal uses `PERSONAL`. Values are resolved only at process startup.
- `runtime-file`: use a user-owned private regular file
  `~/.config/fleet/secrets/work/mcp/example-api.json` (or personal) containing
  exactly the declared keys and nonempty string values. Use mode 0600, no symlink
  components. Malformed/permission errors are redacted without printing contents.
- HTTP runtime authentication supports Bearer `API_ACCESS_TOKEN` only, through
  pinned `mcp-proxy` 0.12.0 in streamable-HTTP **client** mode. Credentials travel
  in its environment, not argv; it creates no listening daemon.
- Native HTTP OAuth is permitted only with `context = "any"`, intentionally
  shared across contexts and using the harness's user-owned login cache.
  Context-restricted HTTP OAuth selections fail until a supported scoped adapter
  exists. Declaring metadata does not implement an OAuth protocol.

Provision secrets separately with local secure storage, `sops`/`age` or an
external credential service. This repository contains no encrypted/plaintext
credential material, automatic login or runtime secret provisioning. Native
user-managed MCPs remain outside fleet policy. Orca Settings is not a second
registry; agents use their harness adapter.

## Validation and acceptance

`checks.x86_64-linux.ai-environment` checks both host contexts, six skill
frontmatters/links, JSON/TOML adapters and rejection cases. Temporary-home tests
exercise preservation, idempotence, disabling, dry-run, collisions, symlinks and
write-failure compensation. Process tests cover simultaneous work/personal
OpenCode overlays, JSONC, positional projects, runtime secret permissions and
MCP wrong-context refusal. No real model/MCP/account is contacted.

Run formatting, flake checks and both system/Home activation builds. After
separately deploying reviewed main, run `ai-doctor`, start fresh harnesses and
check skill discovery and Claude's RTK summary versus exact output. Kiro's
`kiro-cli agent validate --path ~/.kiro/agents/nixos-fleet.json` requires runtime
login even for validation; build tests verify the generated structure.
Builds cannot establish model behavior, GUI health or successful authentication.

[Orca](orca.md) is enabled in the shared daily profile through
`fleet.ai.orca.enable`, while its sessions/settings remain user-owned.
[Artemis](artemis.md) installation and per-harness MCP allowlist remain disabled
by default, including OpenCode. They add no automatic trust or Android tasks.

## References

- [Codex instructions](https://learn.chatgpt.com/docs/agent-configuration/agents-md) and [skills](https://learn.chatgpt.com/docs/build-skills)
- [Claude memory](https://code.claude.com/docs/en/memory) and [hooks](https://code.claude.com/docs/en/hooks)
- [Kiro steering](https://kiro.dev/docs/steering/) and [agents](https://kiro.dev/docs/custom-agents/configuration-reference/)
- [OpenCode configuration](https://opencode.ai/docs/config/) and [Agent Skills](https://opencode.ai/docs/skills/)
- [mcp-proxy authentication/client mode](https://github.com/sparfenyuk/mcp-proxy)
- [RTK hooks](https://github.com/rtk-ai/rtk/tree/develop/hooks)
