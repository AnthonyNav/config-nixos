# Maintainer Guide

## Architecture

`flake.nix` is the entry point for a single user, `anthony`, across the inventory
in `inventory/hosts.nix` (currently three workstations). `flake/hosts.nix`
composes a shared Home Manager base, a selected desktop style, and a host overlay
that chooses its development role and hardware-specific user configuration.

| Host | Graphics | Home features |
|---|---|---|
| `victus` | AMD iGPU + NVIDIA PRIME | Creative suite, AMD monitoring |
| `desktop` | NVIDIA only | Creative + ML profile, fixed three-monitor profile |
| `thinkpad` | Integrated graphics | Development-only profile, network diagnostics |

The installer ISO is not a workstation and does not import Home Manager.

`desktopStyles` is a closed registry in `flake/hosts.nix`. All current hosts select
`caelestia`, whose system and Home Manager modules live in
`desktops/caelestia/`. Add a style to that registry instead of creating a
long-lived branch per desktop implementation.

## Fleet and laboratory boundaries

`inventory/fleet.nix` derives separate host sets for SSH, Syncthing, input
sharing, lab capabilities, workstation/server kinds and Home Manager outputs.
Each host declares its own Nix platform. A server can use
`desktopStyle = null; homeModules = null;` without importing GUI or user
development profiles. A non-null Home module list must provide the user's
Home Manager identity and state version.

`modules/system/common.nix` owns shared administration;
`workstation.nix` adds desktop services and Docker; `server.nix` disables
sleep and defaults to one Nix job/core. Real server resource tuning still needs
hardware measurements. K3s, CI agents and publication are opt-in modules under
`modules/system/lab-platform/`. Desktop and Victus declare the same
Kubernetes/CI capabilities, with no enabled instances. Both use the shared
creative/ML workstation profile and Docker socket activation. See
[desktop-workstation.md](desktop-workstation.md) for the Desktop transition
and preservation of its former infrastructure data.

`nix-config build all all` builds each system and only its declared Home output.
`build home <host>` reports an error for a host without Home Manager.
CI derives the same conditional matrix from `lib.buildMatrix`. Runners and
maintenance tooling currently target x86_64 Linux; Darwin is out of scope.
The `fleet-policy` check covers a synthetic headless host, opt-in Victus lab
instances and invalid configurations; `headless-system` builds that fixture.
The fixture is never exported as a deployable host.

See [lab-platform-plan.md](lab-platform-plan.md) for configuration examples
and the deferred IdeaPad hardware gate.

## Planned platform evolution

Future fleet, laboratory, AI-environment, project-isolation and Darwin work is
tracked in [fleet-platform-evolution.md](fleet-platform-evolution.md). Treat
that document and its linked plans as implementation guidance only: existing
runtime behavior remains authoritative until each phase is implemented,
validated and merged through its own PR.

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
nix-config build system thinkpad
nix-config build home thinkpad
nix-config build all thinkpad
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
- `~/.config/caelestia/shell.json` is mutable. Home Manager seeds it once from
  `modules/home/caelestia.nix`; do not restore `programs.caelestia.settings`,
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
  `colors:_var:_type` and `colors:_var:expr` options. Hyprland colors remain
  explicitly defined in `modules/home/hyprland.nix`.
- Kitty control sockets are PID-suffixed. Reload code must glob `/tmp/kitty-*`.
- Pritunl is a system module because its daemon needs root.
- The creative suite is imported only by NVIDIA hosts. The Blender launcher and
  desktop entry require `LD_LIBRARY_PATH=/run/opengl-driver/lib`.
- ThinkPad is development-only. It must not import `creative-suite.nix`, GPU
  launchers, Blender, Resolve, or fixed desktop monitor rules.

## Host-Specific Changes

See [resource-policy.md](resource-policy.md) for build concurrency, ThinkPad's
encrypted swap and on-demand Docker, measurement criteria, and rollback.

Keep generated `hardware-configuration.nix` files local to their host. Put
system hardware settings in `hosts/<name>/default.nix` and Home Manager
features in `hosts/<name>/home.nix`. A common module must never assume PRIME,
NVIDIA, a fixed monitor layout, or an AMD GPU.

When changing a shared profile, evaluate all hosts. When changing NVIDIA or
creative behavior, build both `victus` and `desktop`; PRIME and direct NVIDIA
are different runtime paths. Keep Wi-Fi experiments in
`hosts/thinkpad/default.nix` and follow `docs/thinkpad-network.md`.

Caelestia, Hyprland, lock/idle, Zsh, and development-profile changes are shared
by all three workstations. Build the NixOS and Home Manager outputs for
`thinkpad`, `victus`, and `desktop` before activation.

### Desktop infrastructure retirement

Desktop's K3s instance, both Woodpecker agents, UI forwarding, Serve/Funnel
publication and persistent Zellij web terminal have been removed from the
declared workstation configuration. Existing runtime data and credentials are
retained. Follow [desktop-workstation.md](desktop-workstation.md) after the
reviewed change is published on `main`; development builds do not stop active
services or remove existing Tailscale publications.

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
the CLI is included on all three workstations. `herdr` is pinned to a release
tag as a flake input and is also included on all three workstations. Update
Herdr through its flake input, not its self-updater.

Orca's [workstation application](orca.md) is enabled on Victus, Desktop and
ThinkPad, pinned in `packages/orca-ide.nix` and exposed as `.#orca-ide`.
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
layout that the source-built `llm-agents` package lacks; without the wrapper
`codex` fails with "this CLI has no complete local package". Remove the wrapper
once the pinned package ships that layout.

Update this toolchain only on a dedicated branch and PR:

```sh
nix flake update llm-agents
nix eval --json .#lib.aiToolVersions
nix fmt
nix flake check --no-build --no-write-lock-file
nix build --no-link --print-build-logs .#checks.x86_64-linux.ai-tools
```

Then perform the required NixOS and Home Manager builds for all three
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

OpenCode is installed without repository-managed wrappers, providers, agents,
commands, skills, or plugins. Its configuration and credentials remain user-owned.
The shared [AI environment](ai-environment.md) adds fleet context and five
skills for Codex, Claude Code and Kiro. Mutable settings stay user-owned; an
activation reconciler updates only recorded fleet entries and preserves local
permissions, credentials and unrelated hooks. MCP enablement defaults to empty.
Run `ai-doctor` after an authorized deployment to check the local integration.

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
`CONTRIBUTING.md` before opening a PR. CI formats, evaluates, builds the
repository policy checks, and plans both the NixOS and Home Manager output for
every workstation without building their closures. Full workstation builds
remain a local validation. Branch protection must require those checks and a
review.

## External Artifacts

Blender's CUDA/OptiX build and themed wallpapers are activation-time downloads.
They are explicit exceptions to Nix store reproducibility. Keep their version,
hash, owner, update procedure, and validation command documented when changing
them; do not let them become unpinned host-local dependencies.

## Optional Artemis runtime

See [artemis.md](artemis.md) for the pinned Android automation runtime, separate
installation/MCP controls, runtime credential ownership and rollback. Default
host profiles do not install or connect Artemis. Never use its upstream global
installer to modify files owned by Home Manager.
