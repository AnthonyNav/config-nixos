# OpenCode

OpenCode is installed as the upstream package from the pinned `llm-agents` flake input.
This repository does not manage OpenCode providers, agents, commands, skills, plugins,
permissions, or project configuration for normal sessions.

## Runtime ownership

OpenCode owns its normal user state and configuration. Configure it through the
standard OpenCode mechanisms under the user's XDG directories or inside an individual
project when needed. Nix only owns the installed binary/version.

Do not use `opencode upgrade`; the executable lives in the Nix store. Update it by
updating the `llm-agents` input in a dedicated branch and PR:

```sh
nix flake update llm-agents
nix eval --json .#lib.aiToolVersions
nix fmt
nix flake check --no-write-lock-file
```

Claude Code, Codex, OpenCode, and RTK share that pinned tool input so their versions
remain reproducible across workstations.

## Project-specific configuration

Prefer project-local OpenCode configuration when a repository needs special tools,
MCP servers, permissions, agents, or instructions. This keeps unrelated projects and
workstations from inheriting extra context or privileges.

Secrets and provider credentials remain local and must never be committed to this
repository or embedded in Nix expressions.
