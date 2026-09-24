# Maintainer Guide

## Architecture

`flake.nix` is the entry point for a single user, `anthony`, on three
workstations. It composes a shared base, development and database-tools Home
Manager profiles, a selected desktop style, and a host overlay.

| Host | Graphics | Home features |
|---|---|---|
| `victus` | AMD iGPU + NVIDIA PRIME | Creative suite, AMD monitoring |
| `desktop` | NVIDIA only | Creative suite, fixed three-monitor profile |
| `thinkpad` | Integrated graphics | Development-only profile, network diagnostics |

The installer ISO is not a workstation and does not import Home Manager.

`desktopStyles` is a closed registry in `flake.nix`. All current hosts select
`caelestia`, whose system and Home Manager modules live in
`desktops/caelestia/`. Add a style to that registry instead of creating a
long-lived branch per desktop implementation.

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
- Kiro Gateway source is pinned as the `kiro-gateway` flake input. Its `.env`
  remains local in `~/.config/kiro-gateway/` with mode `0600` and its venv in
  `~/.local/share/kiro-gateway/`; Nix manages the provider and seed models but
  never selects Kiro by default. `kiro-gateway-bootstrap` detects only
  `~/.aws/sso/cache/kiro-auth-token.json` or the Kiro CLI SQLite database after
  validating any configured credential path, creates the local secret file, and
  enables its catalog only after service startup and model sync succeed. The
  gateway discovers the account catalog from `management.<region>.kiro.dev`;
  the `kiro-opencode-model-sync` timer writes its mutable models overlay under
  XDG state using the managed config as `--base-config`. Validate it with a real
  completion, not only `/health` or `/v1/models`.
- Use Kiro model ID `auto`, never `auto-kiro`.
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

### Desktop Woodpecker agents

Desktop runs separate Docker agents for backend/Testcontainers work and the
Estoma frontend. `woodpecker-agent-frontend` advertises only
`repo=AnthonyNav/estoma-app`, has one workflow slot, and keeps its agent config
in the `woodpecker-agent-frontend-config` Docker volume. Do not replace the
repository label with a wildcard or add frontend work to the existing
`woodpecker-agent-desktop` service.

Both desktop agents connect to the same local Woodpecker gRPC forward. The
frontend agent requires its own `/etc/woodpecker/agent-frontend.env`, owned by
root with mode 0600, containing `WOODPECKER_AGENT_SECRET` for a dedicated agent.
An administrator creates that agent in Woodpecker Settings → Agents → Add agent
and provisions the token securely on the host, never through chat or Git.
Do not assume the backend agent token can be reused. The host configuration
does not provision this identity or registry credentials. Repository-scoped
GHCR credentials belong in Woodpecker's secret storage and must never be added
to this repository or the host env file. After the reviewed change reaches
`main`, deploy through `nix-update`; then verify the new unit and container
before retrying queued frontend workflows.

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

DbGate Community is pinned in `packages/dbgate.nix` for `victus` and exposed
as `.#dbgate`. Database connections and credentials stay in local application
state, never in this repository. DBeaver is pinned in `packages/dbeaver.nix`
for `desktop` and exposed as `.#dbeaver`.

## OpenCode

Claude Code, Codex, OpenCode, and RTK come from the pinned `llm-agents` flake
input. This keeps these agent tools current without coupling their updates to a
full `nixpkgs` refresh. The input intentionally uses its own tested Nixpkgs
revision and the signed Numtide binary cache declared in `flake.nix`; do not add
`inputs.nixpkgs.follows` unless the resulting source builds have been evaluated
as an explicit tradeoff. The same cache and signing key are configured for the
Nix daemon in `modules/system/core.nix`, preventing local Codex and RTK source
builds after the first deployment. Inspect the pinned versions with
`nix eval --json .#lib.aiToolVersions`.

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
daemon settings from `modules/system/core.nix` and need no bootstrap step.

`opencode/opencode.json`, agents, commands, shared skills, the RTK plugin, and
the `opencode` and `opencode-work` wrappers are deployed by
`modules/home/opencode.nix`. OpenCode starts without requiring Kiro as its
default model. After a successful `kiro-gateway-bootstrap`, both wrappers read
only `PROXY_API_KEY` from the private gateway `.env`; normal `opencode` also
merges the generated models catalog, while isolated `opencode-work` retains the
immutable seed catalog. The key must never enter Nix.
`~/.local/state/opencode/kiro-models.json` is mutable generated state and must
not be hand-edited. Restart OpenCode after a
configuration, agent, command, skill, plugin, or catalog change.

Run `/work` only inside `opencode-work`. That launcher isolates global and
project config, external plugins, Claude compatibility instructions and skills,
LSPs, formatters, and late caller overrides before loading the deny-by-default
control plane and seed provider config from the Nix store. `/work` can only
inspect and produce a contract; the user must invoke `/work-apply <revision>`
to expose the managed implementer. The apply agent rechecks clean tracked
state, ignored-state integrity, and symlink absence before delegating
independent review. Neither command commits, publishes, deploys, or activates.

`nix build --no-link .#checks.x86_64-linux.opencode-workflow` executes the real
wrapper and validates config isolation, effective tools, exact allowlists, and
resistance to global/project plugins, conflicting managed names, and late
environment overrides.

Activation fails rather than deleting user data when either legacy
`~/.claude/skills/graphify` or `~/.config/opencode/plugins/rtk.ts` remains.
Review and archive or remove the reported path manually before retrying.

See `docs/opencode.md` for managed skills, context limits, and opt-in MCP
examples. Do not enable a credential-bearing MCP globally or commit its token.

Claude Code remains installed as a secondary CLI. Its local configuration under
`~/.claude` is not managed by this repository, preserving the upstream
first-run experience.

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

## Optional Local Services

`profiles/system/local-mariadb.nix` is not imported by any host. Import it
only in a host module that needs a local MariaDB daemon; database GUIs and
`usql` are clients supplied by the shared `database-tools` profile.
