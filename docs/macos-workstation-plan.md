# macOS workstation portability plan

## Status

Implemented portability foundation for adding an Apple Silicon MacBook Pro (M5-class,
`aarch64-darwin`) to the development fleet without trying to make macOS behave
like NixOS.

The goal is to reuse the **development experience** while keeping operating
system responsibilities separate.

No Darwin host should be added to deployable outputs until the real Mac exists
and its hostname/user requirements are known.

The real Apple M5 Mac is registered as `MacBook-Pro-de-Antonio`, with user
`anthonynav`, home `/Users/anthonynav`, and development, platform and mobile
profiles. Its system output is `darwinConfigurations.MacBook-Pro-de-Antonio`.
`inventory/darwin-template.nix` still provides the host shape for future Macs.
Darwin system and Home fixtures remain under `checks.aarch64-darwin`, with Linux
evaluation in `checks.x86_64-linux.darwin-evaluation` and native macOS CI builds.
Registration does not prove native activation or application readiness; follow
the [onboarding runbook](macos-onboarding.md) for acceptance on the real device.

The implementation keeps existing paths: `profiles/home/base.nix` and common
modules own portable behavior, `profiles/home/linux.nix` owns Linux behavior,
`profiles/home/darwin.nix` owns Darwin adapters, and `modules/darwin` owns the
macOS system. There is no directory-wide relocation.

Portable AI CLIs are Codex, Claude Code, OpenCode and RTK from the locked
`llm-agents` input. Kiro's Linux wrapper and Herdr are retained on Linux;
Darwin does not silently install unsupported Linux packages or require their
presence in `ai-doctor`. Optional Artemis remains off and needs separate native
validation before enabling it on a Mac.

Native ownership is explicit: Homebrew manages Orca, standalone `tailscale-app`,
VS Code with the development profile, Android Studio with the mobile profile,
and Colima with development. Nix owns Docker-compatible clients; Colima is
installed without starting a VM. The mobile Home profile provides FVM and
CocoaPods; Xcode and project Flutter SDKs stay external to the workstation's
common package set. Homebrew activation disables automatic
updates, upgrades and cleanup of unrelated applications.

Register Orca's native `orca` CLI in its settings after installation. The Darwin
`orca-ide` adapter preserves shared workspace and skill commands. Tailscale's
adapter invokes the standalone app binary; it does not install a second daemon.

Evaluating Darwin on Linux does not prove Darwin builds, first activation,
native GUI behavior, connectivity or mobile workflows. Native CI performs builds
and portable contract tests; acceptance on the real Mac remains in onboarding.

## Target architecture

```text
                     shared development layer
                              │
                ┌─────────────┴─────────────┐
                │                           │
              NixOS                       macOS
       nixosSystem + Home Manager   nix-darwin + Home Manager
                │                           │
       Linux/systemd/hardware       Darwin/launchd/native apps
```

The shared layer should contain:

- workspace commands and `HANDOFF.md` workflow;
- work/personal/neutral identity routing;
- Git/SSH/GitHub/AWS helpers;
- Zsh and terminal tooling;
- Neovim/editor-independent tooling;
- direnv/nix-direnv;
- project `nix develop` environments;
- AI context, skills and MCP registry/policy;
- Codex, Claude Code, OpenCode and other Darwin-supported AI CLIs;
- `fleet-info`, `ai-doctor`, workspace helpers and engineering standards;
- Orca workflow and remote-runtime conventions;
- general platform/cloud/security CLI tooling when packages support Darwin.

Platform-specific layers own everything else.

## Inventory

Evolve the inventory so platform/system are host properties rather than
hard-coded Linux assumptions.

Target:

```nix
desktop = {
  system = "x86_64-linux";
  platform = "nixos";
};

victus = {
  system = "x86_64-linux";
  platform = "nixos";
};

macbook = {
  system = "aarch64-darwin";
  platform = "darwin";
};
```

The Mac should be a normal workstation, not a special exception sprinkled
through common modules.

## Configuration composition

Target shape:

```text
platforms/
├── nixos/
└── darwin/

home/
├── common/
├── linux/
└── darwin/

ai/
workspace/
inventory/
```

Equivalent existing paths may be retained if a smaller refactor gives the same
ownership boundary; directory renames are not a goal by themselves.

### Common Home Manager

Move only portable behavior into the common layer.

Examples:

- Git/SSH identity policy;
- shell functions/aliases that do not depend on Linux;
- workspace CLI;
- handoff workflow;
- AI context/skills/MCP adapters;
- editor configuration supported on both platforms;
- project environment helpers;
- general developer CLIs.

### Linux-only

Keep out of Darwin evaluation:

- Hyprland/Caelestia;
- systemd user/system services;
- NixOS firewall;
- NVIDIA/PRIME/CUDA host configuration;
- ZRAM/swap;
- Pritunl NixOS daemon;
- Linux input sharing modules;
- Linux-only sandbox dependencies such as Bubblewrap/nsjail;
- AppImage/.deb wrappers;
- NixOS hardware/boot modules.

### Darwin-only

Use nix-darwin/Home Manager/launchd for:

- macOS defaults and system configuration;
- launch agents;
- native application ownership;
- Apple Silicon-specific packages;
- Xcode/Command Line Tools integration;
- Darwin container runtime;
- native macOS sandbox behavior;
- platform-specific GUI applications.

## Home paths

Never encode `/home/<user>` in portable code.

Use Home Manager/user configuration:

```nix
config.home.homeDirectory
```

Expected paths:

```text
NixOS: /home/anthony
macOS: /Users/anthony
```

Therefore the same logical workspace remains:

```text
$HOME/Workspace/work
$HOME/Workspace/personal
```

## nix-darwin + Home Manager

Add nix-darwin as a flake input following the same Nixpkgs revision as the
fleet where practical.

The Darwin constructor should compose:

```text
nix-darwin system modules
+ Home Manager nix-darwin module
+ common Home
+ Darwin Home
+ explicit host exceptions
```

Do not import Linux desktop/system modules and then hide failures with many
conditionals.

Home Manager should be a nix-darwin module so one reviewed activation builds
the system and user environment together.

## Application ownership

Prefer Nix packages for portable CLI/development tools.

Use nix-darwin-managed Homebrew/casks only when a native macOS application is
better supported there.

Examples to evaluate:

- Orca: official macOS Apple Silicon distribution/Homebrew cask;
- Tailscale: platform-native standalone app because it owns a macOS network
  extension;
- GUI IDEs where upstream macOS packaging is preferable;
- container runtime.

Do not duplicate the same application through both Nix and Homebrew.

## AI environment

Add:

```text
ai/context/darwin.md
```

The generated context must identify:

```text
OS: macOS
Platform: aarch64-darwin
Host: macbook
Kind: workstation
Workspace context: work|personal|neutral
```

Common engineering standards, handoff rules, orchestration rules and skills
remain identical.

Darwin differences belong only in `darwin.md` or platform adapters.

Examples:

- no `apt`/NixOS instructions;
- use nix-darwin for system-managed configuration;
- use launchd instead of systemd;
- use the agent's native macOS sandbox instead of Linux Bubblewrap/nsjail.

## Workspaces and source code

Workspace layout is unchanged:

```text
~/Workspace/
├── work/<workspace>/
└── personal/<workspace>/
```

Syncthing may carry:

- `HANDOFF.md`;
- docs;
- assets;
- approved non-Git workspace files.

It must continue excluding:

- `repos/`;
- worktrees;
- `.git/`;
- caches/build output;
- credentials/secrets;
- agent/Orca mutable state.

Repos are reconstructed using the portable handoff:

```text
HANDOFF
-> clone/fetch repos
-> checkout active branches/WIP
-> load project environment
-> continue
```

WIP commits may transport unfinished work between hosts, but must be cleaned
before PR review/audit/merge.

## Identity portability

Never synchronize credential files directly.

The same logical identities exist on every workstation, but each Mac creates or
imports its own authorized credentials locally:

- personal/work SSH keys;
- GitHub CLI sessions;
- AWS SSO profiles/cache;
- agent logins;
- Orca pairing state;
- MCP OAuth/tokens.

The fleet configuration supplies policy and paths, not secret material.

`workspace-context`, managed Git, `gh`, AWS wrappers and diagnostics should
behave the same on Darwin.

## Orca

The Mac should support both:

1. autonomous local Orca development;
2. client access to Desktop's primary headless Orca runtime over Tailscale after
   its reviewed-main deployment and explicit pairing; see [Orca](orca.md).

Desktop remains optional. If it is offline, the Mac must still be able to clone
repos from their normal remotes and work locally.

Do not synchronize Orca database/session state between operating systems.

## Syncthing

Reuse the same folder IDs/policy model, adapted to Darwin service ownership.

Preferred architecture:

- Syncthing package owned declaratively;
- Home Manager/launchd owns the user daemon;
- existing fleet reconciliation logic is made platform-neutral where possible;
- paths derive from `homeDirectory`;
- only approved hosts participate in each folder.

Do not create a second manually-maintained Syncthing policy for macOS.

## Tailscale

Treat Tailscale as a platform-owned native macOS component.

Use the official standalone macOS application/network extension and enable its
CLI integration for diagnostics.

The tailnet policy remains the same external policy source; adding the Mac
requires an explicit peer/host policy review.

## Containers

Share Docker-compatible CLI/project behavior where possible, but keep the
runtime Darwin-specific.

Do not pretend the NixOS Docker daemon module is portable.

Evaluate one macOS runtime explicitly (for example Colima, OrbStack or Docker
Desktop) and document its ownership before enabling it.

Project Compose files should remain portable when the project itself supports
both OSes.

## Mobile development

The Mac may select the development/mobile capability.

Darwin-specific validation must cover:

- Flutter;
- Android SDK/emulator;
- Artemis device automation where supported;
- Xcode;
- iOS simulator/device workflow;
- CocoaPods/SPM if required by projects.

Xcode and Apple SDK licensing/installations remain platform-owned and cannot be
reproduced fully through Nix.

## Validation

Add Darwin-specific evaluation/build outputs.

Linux CI must not be considered proof of Darwin correctness.

Required validation on the real Mac:

- nix-darwin evaluation/build;
- Home Manager activation;
- shell/Git identity routing;
- work/personal/neutral contexts;
- workspace creation/status;
- clone/resume from a HANDOFF;
- AI skill/context discovery;
- Codex/Claude/OpenCode startup;
- Orca local + Desktop remote connection;
- Tailscale;
- Syncthing ignores/folder scope;
- project `nix develop`;
- container runtime;
- Flutter/Android and iOS workflows when selected.

## Acceptance criteria

- Mac is `aarch64-darwin` in the same inventory model.
- NixOS modules never evaluate for the Mac.
- Common Home/AI/workspace policy is shared instead of copied.
- macOS receives a generated Darwin host context.
- credentials remain local and separated by work/personal context.
- workspace handoffs move cleanly between Linux and macOS.
- Git, not Syncthing, moves repository history/source.
- Orca can run locally and connect to Desktop remotely.
- disabling/removing the Mac does not change the behavior of Desktop/Victus.
