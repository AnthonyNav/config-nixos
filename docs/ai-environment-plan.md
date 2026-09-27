# Global AI Environment Plan

## Goal

Provide one declarative source of truth so every supported AI harness knows:

- the current operating system and host role;
- how Nix-managed machines must be modified;
- which reusable skills are available;
- when RTK should be used;
- which MCP servers are known and enabled;
- what belongs to system, Home Manager or project configuration.

This document defines architecture only.

## Canonical source

```text
ai/
├── context/
│   ├── global.md
│   ├── nixos.md
│   ├── darwin.md
│   └── generated-host.md
├── skills/
│   ├── nixos-maintenance/SKILL.md
│   ├── project-bootstrap/SKILL.md
│   ├── pr-review/SKILL.md
│   ├── nix-debugging/SKILL.md
│   └── mcp-management/SKILL.md
└── mcp/
    ├── registry.nix
    └── policy.nix
```

The generated host context must come from evaluated fleet metadata instead of
being maintained manually.

## Global context

Keep always-loaded context intentionally small. It should state rules such as:

- the machine is managed declaratively with Nix;
- do not use apt/dnf/pacman;
- do not modify `/nix/store`;
- system software belongs in NixOS/nix-darwin;
- user tools belong in Home Manager;
- project SDKs/dependencies belong in project environments;
- prefer `nix run`/`nix shell` for temporary tools;
- prefer `nix develop` + direnv for project environments;
- prefer RTK for supported shell commands;
- never commit secrets/runtime credentials;
- never activate/deploy Nix feature branches;
- inspect existing modules/profiles before creating abstractions.

Long procedures belong in skills, not global context.

## Platform context

`nixos.md` should contain NixOS-specific operational rules: configuration is
the source of truth, format/evaluate/build before activation, inspect systemd
and Nix state rather than guessing, and follow branch -> validation -> PR ->
main -> activation.

A future `darwin.md` contains only macOS/nix-darwin differences.

## Host context

Generate facts such as:

```text
OS: NixOS
Host: victus
Platform: x86_64-linux
Kind: workstation
Capabilities: development, lab-platform, kubernetes, ci, gpu-compute
Graphics: nvidia-prime
```

or:

```text
OS: NixOS
Host: ideapad
Kind: server
Resource class: legacy-low
Capabilities: deployment-lab, ssh, tailscale, selected lab components
```

Do not duplicate changing hardware facts in multiple AI files.

## Harness adapters

Home Manager should expose canonical context/skills in the global
locations/formats expected by supported harnesses such as Codex, Claude Code,
OpenCode and Kiro.

Canonical content remains harness-independent. Tool-specific file names,
JSON/TOML syntax and integration behavior belong in adapters.

## Skills

Use reusable skills for procedures. Initial candidates:

- `nixos-maintenance`;
- `project-bootstrap`;
- `nix-debugging`;
- `pr-review`;
- `mcp-management`.

Prefer one canonical `SKILL.md` source where harnesses support the common
Agent Skills structure.

## RTK

RTK is already installed, but installation does not guarantee usage.

Target behavior:

1. use command-interception hooks/plugins where supported;
2. retain a global instruction to prefer RTK as fallback;
3. fall back to the original command when RTK does not support it.

Do not rely only on prose when an integration can enforce the behavior.
Validate that hooks preserve command semantics.

## MCP registry

Separate known MCPs from enabled MCPs:

```text
registry = MCP servers known to the environment
policy   = MCP servers enabled for a host/harness/context
```

A registry entry should eventually describe ID/name, source/owner, transport,
endpoint/command, authentication model, required secret names, supported
harnesses, default enabled state and trust notes.

Do not enable every registered MCP globally.

## Secrets

Never place MCP API keys/tokens directly in Nix expressions or generated files
that expose them through the Nix store.

Before declarative secret delivery, choose and document a runtime secret
mechanism such as sops-nix or agenix. Registry metadata can be declarative
while credentials remain runtime-owned.

## Diagnostics

After this layer exists, add an `ai-doctor`-style command able to report:

- host/platform/kind;
- installed harnesses;
- global context presence;
- discovered skill count;
- RTK availability/integration;
- registered/enabled MCP count;
- missing expected configuration.

External authentication/network success must not become a build-time
requirement.

## Checks

Validate:

- context generation for each applicable host;
- generated host facts match inventory;
- skill directory structure;
- no duplicate MCP IDs;
- harness adapter syntax;
- RTK integration files where enabled;
- secret values are not committed into store-backed configuration.

## Acceptance criteria

- One canonical global context feeds supported harnesses.
- Host context is generated from fleet metadata.
- Skills are shared rather than duplicated per agent.
- RTK becomes automatic where the harness permits it.
- MCP registry and activation policy are separate.
- Credentials remain outside the Nix store.
- A future harness requires an adapter, not a duplicated policy set.
