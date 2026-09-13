# Spec Kit multi-agent workflow

GitHub Spec Kit is available as an optional per-project Spec-Driven Development
workflow. Nix/Home Manager owns the helper commands and the default integration
policy; the mutable `specify` CLI itself is installed with `uv tool` so its
official self-update flow remains available.

## Install

The first installation is pinned to the reviewed stable release declared in
`profiles/home/development/spec-kit.nix`.

```sh
speckit-bootstrap
```

The CLI lives in uv's normal tool environment outside the Nix store. This is
intentional: `specify self upgrade` must be able to replace it without changing
the system configuration.

Check the installed version and whether a newer stable release exists:

```sh
speckit-check
```

Upgrade the CLI using Spec Kit's supported installer detection:

```sh
speckit-update
```

Preview an upgrade without changing anything:

```sh
speckit-update --dry-run
```

Pin an explicit release when necessary:

```sh
speckit-update --tag v1.0.6
```

## Initialize a project

From the repository root:

```sh
speckit-init
```

Codex is the default integration. The helper also installs Claude Code, Kiro CLI
and OpenCode so the same Spec Kit project can be used from any of those tools.
The default can be selected at initialization:

```sh
speckit-init claude
speckit-init codex
speckit-init kiro-cli
speckit-init opencode
```

The project keeps one default integration, but all installed integrations share
the durable Spec Kit artifacts. Agent-specific commands/skills are generated in
separate roots:

- Claude Code: `.claude/skills/`
- Codex CLI: `.agents/skills/`
- Kiro CLI: `.kiro/prompts/`
- OpenCode: its Spec Kit integration directory managed by `specify`

Claude, Codex and Kiro CLI are declared multi-install safe by Spec Kit. OpenCode
is supported but is not currently declared multi-install safe, so the helper
explicitly opts into that combination with `--force` during installation.

The shared project state remains under `.specify/` and the generated feature
artifacts under `specs/`. Commit these project artifacts according to the
project's normal source-control policy.

## Change the active agent

Spec Kit keeps one default integration because some shared templates,
extensions and presets are default-sensitive. Change it without uninstalling the
others:

```sh
specify integration use codex
specify integration use claude
specify integration use kiro-cli
specify integration use opencode
```

This does not remove the other integrations.

## Upgrade an existing project

Updating the CLI does not automatically rewrite already generated agent
integrations. After a CLI update, enter each Spec Kit project and run:

```sh
speckit-sync-agents
```

The helper reads `.specify/integration.json`, upgrades every installed
integration, and reports the resulting state. It deliberately does not pass
`--force` during upgrades so locally modified managed files are not silently
overwritten.

For diagnostics:

```sh
specify integration status
specify integration status --json
```

## Daily model

System-wide concerns:

```text
Nix/Home Manager
  -> uv + helper commands
  -> default integration policy: codex
```

User-managed CLI:

```text
uv tool
  -> specify-cli
  -> specify self check / upgrade
```

Project-owned state:

```text
repository
  -> .specify/
  -> specs/
  -> Claude integration
  -> Codex integration
  -> Kiro CLI integration
  -> OpenCode integration
```

This keeps Spec Kit agent-independent: one agent can create a specification,
another can refine the plan, and another can implement it without replacing the
underlying spec/plan/task artifacts.
