# Maintainer Guide

## Architecture

The inventory currently contains Desktop and Victus. Both consume one daily
Home environment and select development, data-science, creative and platform profiles.
Hardware modules stay under `hosts/<name>/`; explicit per-program Home modules
and static `dotfiles/` are shared. See [workstation-architecture.md](workstation-architecture.md)
for extension rules, [monitors.md](monitors.md) for topology selection and
[workstation-research.md](workstation-research.md) for update decisions.

`flake/hosts.nix` composes NixOS, Home Manager and a registered desktop style.
All inventory members are daily workstations with Home Manager; the installer
is a separate output. SSH, Syncthing, input-sharing peers and CI's build matrix
are inventory-derived. Shared changes require two systems and two Home builds.
The integrated-GPU fixture verifies the daily environment without development,
creative, compute or virtualization dependencies; it is not deployable.

Local Docker and virt-manager/libvirt remain. Server provisioning, CI agents,
headless profiles, public/web-terminal publication and ThinkPad are retired.
Removing their declarations never authorizes deletion of local data or external
identities. This repository does not publish tailnet policy or deploy itself.

`desktopStyles` is a closed registry in `flake/hosts.nix`. Current machines use
Caelestia. New desktop variants belong there, not in permanent branches.

## Commands

Format and fully validate the current workstation without activation:

```sh
nix-format
nix-check
```

Validate and build every NixOS and Home Manager workstation output:

```sh
nix-check all
```

Build a narrower scope without activation when appropriate:

```sh
nix-config build system victus
nix-config build home victus
nix-config build all victus
```

Receive the reviewed configuration from `main`, validate it, and apply it:

```sh
nix-update
```

Apply an already published `main` without updating Git:

```sh
nix-switch
nix-home-switch
```

`nix-home-switch` selects `anthony@$(hostnamectl --static)` and must not use a
generic profile because that would omit host-specific features. Every switch
requires clean `main` to equal freshly fetched `origin/main`; feature branches
may format, check, and build, but never activate. `nix-update` is the only
normal command that modifies Git before deployment. See `docs/nix-config.md`.

## Non-Negotiable Invariants

- Caelestia owns files it dynamically renders, including GTK output, Kitty
  colors, and rendered template targets. Home Manager manages the Kitty
  template source, not the Caelestia-rendered output.
- `~/.config/caelestia/shell.json` is mutable. Home Manager seeds it from
  `modules/home/caelestia.nix` and merges absent personalization fields; do not restore `programs.caelestia.settings`,
  because the upstream module would replace it with a read-only store symlink
  and Nexus could no longer persist changes.
- Caelestia is the shell; Hyprland owns window navigation, scratchpad,
  mouse move/resize, and Alt-Tab. Verify syntax against the installed
  Hyprland before adding window or layer rules.
- Caelestia Lock is the only session locker. Hypridle owns idle timing, DPMS,
  and suspend, but must not start Hyprlock alongside Caelestia's
  `ext-session-lock` client.
- The Catppuccin mode wrapper must override both the Caelestia CLI and shell
  package. The shell has its own wrapped internal PATH.
- The Caelestia Wi-Fi patch is shared by all desktop hosts. Preserve its
  invariants when rebasing it: no preventive disconnect, saved profiles by
  UUID, one callback per command, no BSSID pin, and no automatic profile delete
  after authentication failure.
- NixOS global Zsh must leave `compinit` and prompt setup to Home Manager. The
  Home Manager completion block deduplicates standard Zsh function directories
  while retaining site and vendor completions.
- Keep `catppuccin.hyprland.enable = false` while
  `wayland.windowManager.hyprland.configType = "hyprlang"`. Catppuccin emits
  a Lua `colors._var` block that Hyprlang rejects as unknown
  `colors:_var:_type` and `colors:_var:expr` options. Hyprland has safe static
  defaults overridden by the Caelestia-rendered colour and preset sources.
- Kitty control sockets are PID-suffixed. Reload code must glob `/tmp/kitty-*`.
- Pritunl is a system module because its daemon needs root.
- The creative suite is imported only by NVIDIA hosts. The Blender launcher and
  desktop entry require `LD_LIBRARY_PATH=/run/opengl-driver/lib`.
- Creative profiles require declared NVIDIA capabilities; the daily base must
  remain usable without NVIDIA, creative launchers or SDKs.

## Host-specific changes

Keep generated hardware files local to each host. Put drivers, PCI addresses,
boot/disks and power quirks under `hosts/<name>/`. Select functional Home
profiles in the inventory; optional `homeModules` are narrow exceptions, not
duplicated daily environments. A shared module must not assume direct NVIDIA,
PRIME or AMD. Display identities describe physical desks, not computers.

Build both Desktop and Victus for shared changes. Their GPU paths differ;
evaluation cannot prove rendering/suspend. Follow [resource-policy.md](resource-policy.md)
and perform main-only runtime acceptance after authorized deployment.

## Development command resolution

Interactive Zsh keeps inherited project and Nix paths ahead of manual global
installations in `~/.local/bin`, `~/.local/share/pnpm`, and
`~/.npm-global/bin`. These manual directories remain available at the end of
`PATH`; existing installations and their data are not removed. The
`development-path` flake check covers project precedence, managed commands,
manual-only commands, and repeated initialization.

When a tool still reports an old version after deployment, inspect an
interactive shell, not only a non-interactive SSH command:

```sh
zsh -lic 'whence -a codex; codex --version'
/etc/profiles/per-user/anthony/bin/codex --version
```

Different versions indicate command shadowing rather than necessarily a failed
deployment. The absolute managed path can be used immediately. After deploying
the reviewed shell configuration from `main`, open a new terminal; existing
shells keep their previous environment.

## Kiro, Herdr, and database clients

Kiro CLI and IDE are pinned separately from `nixpkgs` in `packages/kiro.nix`
and `packages/kiro-ide.nix`. The CLI retains Nixpkgs' FHS wrapper for its
embedded Bun runtime. The IDE uses `buildVscode` with the Code OSS version
from the vendor archive. Both packages are exposed as `.#kiro-cli` and
`.#kiro` for build validation. The IDE is included on `victus` and `desktop`;
the CLI is included on both workstations. `herdr` is pinned to a release
tag as a flake input and is also included on both workstations. Update
Herdr through its flake input, not its self-updater.

Orca's [workstation application](orca.md) is enabled in the shared daily profile for Desktop and Victus, pinned in `packages/orca-ide.nix` and exposed as `.#orca-ide`.
Its Linux CLI is `orca-ide`; the application launcher is `orca-ide-gui`.
Update the package version/hash through review and revalidate
upstream's externally-managed-install guard. Mutable application state is local.

DbGate Community is pinned in `packages/dbgate.nix` for `victus` and `desktop` and exposed
as `.#dbgate`. Database connections and credentials stay in local application
state, never in this repository. DBeaver remains pinned in `packages/dbeaver.nix`
and exposed as `.#dbeaver` for optional use through `nix run`.

## AI tool packages

Claude Code, Codex, OpenCode, and RTK come from the pinned `llm-agents` flake
input. This keeps these agent tools current without coupling their updates to a
full `nixpkgs` refresh. The input intentionally uses its own tested Nixpkgs
revision and the signed Numtide binary cache declared in `flake.nix`; do not add
`inputs.nixpkgs.follows` unless the resulting source builds have been evaluated
as an explicit tradeoff. The same cache and signing key are configured for the
Nix daemon in `modules/system/common.nix`, preventing local Codex and RTK source
builds after the first deployment. Inspect the pinned versions with
`nix eval --json .#lib.aiToolVersions`.

`packages/ai-tools.nix` wraps Codex (`packages/codex.nix`) with
`-c features.daemon_auto_start=false`. Since 0.159 Codex starts a shared
app-server daemon by default, which requires the upstream `codex-package.json`
layout that the source-built `llm-agents` package lacks; without this flag
`codex` fails with "this CLI has no complete local package". Remove the daemon
flag once the pinned package ships that layout, retaining the Git/SSH behavior.

The same wrapper sets `GIT_TERMINAL_PROMPT=0` and adds `-o BatchMode=yes` to
the inherited SSH command, preserving the personal-context identity wrapper.
Without an inherited command it uses pinned OpenSSH. Git operations inside
Codex require non-interactive authentication, such as the correct key loaded
in the SSH agent, and fail instead of prompting when it is unavailable. See
[codex-git-prompt-plan.md](codex-git-prompt-plan.md) for the reported TUI issue,
validation scope and real-session follow-up.

Update this toolchain through a reviewed branch and PR; when included in a larger
approved change, keep its dependency update separately identifiable:

```sh
nix flake update llm-agents
nix eval --json .#lib.aiToolVersions
nix fmt
nix flake check --no-build --no-write-lock-file
nix build --no-link --print-build-logs .#checks.x86_64-linux.ai-tools
```

Then perform the required NixOS and Home Manager builds for both
workstations. Do not use `claude update`, `codex update`, `opencode upgrade`, or
another tool's self-updater: those bypass the repository lock and cannot update
binaries in the Nix store.

On the first deployment to a host whose running Nix daemon does not yet trust
the Numtide cache, pre-build the reviewed, published `main` configuration as
root so the flake cache settings can bootstrap the system setting without a
local Codex source build:

```sh
sudo nixos-rebuild build --accept-flake-config --flake .#<host>
nix-update
```

The first command only builds; it does not activate. Later deployments use the
daemon settings from `modules/system/common.nix` and need no bootstrap step.

OpenCode's providers, models, permissions, plugins and credentials remain
user-owned. Its launcher adds fleet context and selected MCPs through a
process-local overlay, preserving JSON/JSONC files. The shared
[AI environment](ai-environment.md) publishes six canonical skills for Codex,
Claude Code, Kiro and universal discovery used by OpenCode/Orca. Mutable settings stay user-owned; an
activation reconciler updates only recorded fleet entries and preserves local
permissions, credentials and unrelated hooks. MCP enablement defaults to empty.
Run `ai-doctor` after an authorized deployment to check the local integration.

Workspace identities are resolved at invocation, with neutral default, separate
GitHub CLI directories and existing read-only AWS profiles. Canonical roots,
external Git worktrees, shared-only Syncthing migration, secret contracts and
rollback are documented in [workspace-workflow.md](workspace-workflow.md).
Keep real credentials outside Git/store. Never use shell display variables as
authentication selectors or restore the global work identity/HTTPS rewrite.

Orca, Bruno and Posting have targeted pins in `packages/`; Postman has a scoped
GTK-schema wrapper. Validate `workspace-context`, `workflow-packages`,
`platform-policy`, `ai-environment` and `syncthing-reconcile` checks plus the
complete flake checks and all four workstation outputs. Built CLI/schema tests
do not replace the per-host GUI, real-account and Android acceptance in
[orca.md](orca.md). Do not activate a feature branch or migrate local data
automatically. The platform profile installs clients only, without workloads.

## Tailnet Policy

`inventory/endpoints.nix` is the source of truth for fleet ports and
`inventory/tailscale.nix` derives the self-scoped grants from it. Render the
policy without credentials:

```sh
nix run .#tailscale-policy
```

The repository does not publish the result to Tailscale. Before deploying a
change that adds or removes an endpoint, compare the rendered JSON with the
active policy and apply the reviewed result from the Tailscale Access controls
page using an Owner, Admin, or Network admin account. Apply policy additions
before deploying the corresponding service; remove obsolete grants only after
the service rollout is complete. Never commit an API token or add unattended
policy mutation to routine PR checks.

## Contributions

All changes use a short-lived branch and a PR to `main`. Read
`CONTRIBUTING.md` before opening a PR. CI formats, evaluates, builds repository
checks and builds NixOS plus Home Manager for every workstation. Require `check`,
`full-build-gate` and one review on main; the desired ruleset is
`.github/main-ruleset.json`. Local full builds are required before review too.
See `CONTRIBUTING.md` for external application and verification of that ruleset.

## External Artifacts

Blender's CUDA/OptiX build and the curated Catppuccin wallpapers are fixed-hash
Nix packages. Activation performs no downloads for them. Update Blender's version
and SHA-256 in `packages/blender-standalone.nix`, and the wallpaper revision and
individual hashes in `packages/catppuccin-wallpapers.nix`. Old local copies remain
user-owned; the store-backed commands no longer use them. Blender uses Nixpkgs
SDL3 and treats optional GPU driver loaders as runtime dependencies. Its headless
check does not prove GPU/GUI health; validate NVIDIA direct and PRIME after
authorized deployment from main.

Appearance is documented in [personalization.md](personalization.md), and backup,
rootless Docker and disk encryption in [recovery.md](recovery.md). Backups and
rootless Docker default off; enabling them requires a concrete destination/data
migration and a reviewed rollout.

## Optional Artemis runtime

See [artemis.md](artemis.md) for the pinned Android automation runtime, separate
installation/MCP controls, runtime credential ownership and rollback. Default
host profiles do not install or connect Artemis. Never use its upstream global
installer to modify files owned by Home Manager.
