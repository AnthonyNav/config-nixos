# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Deploy Commands

```bash
# Rebuild and switch the full system (detects hostname automatically)
nix-switch

# Equivalent explicit form
sudo nixos-rebuild switch --flake .#victus   # or thinkpad / desktop

# Use path: prefix when files are not yet git-tracked
sudo nixos-rebuild switch --flake "path:$PWD#victus"

# Rebuild only the Home Manager profile (no system changes)
hm-switch
# or explicitly
home-manager switch --flake .#anthony

# Garbage-collect old generations
nix-clean
```

`nix-switch` and `hm-switch` are Zsh functions defined in `modules/home/zsh.nix`.

## Architecture

```
flake.nix          # Entry point. Defines username, mkHost helper, hostIfReady guard.
home.nix           # Shared Home Manager config imported by every host.
hosts/<name>/      # Per-machine overrides: hardware, GPU driver, hostname.
modules/home/      # Home Manager sub-modules (Hyprland, Caelestia Shell, Kitty, Rofi [dmenu backend only], Zsh, theme-sync, wallpapers, night-light, lock-idle).
modules/system/    # NixOS system sub-modules (core services, nix-ld/AI helpers, display manager).
```

### Key design decisions

- **Single username**: `username = "anthony"` in `flake.nix` propagates everywhere via `specialArgs`.
- **`hostIfReady`**: hosts without a `hardware-configuration.nix` are silently skipped, so `thinkpad` and `desktop` only appear in `nixosConfigurations` once their hardware file is added.
- **Home Manager is integrated** into each `nixosSystem` (not standalone). Running `nixos-rebuild switch` applies both system config and the user profile. `hm-switch` exists for quick user-only reloads.
- **Catppuccin Mocha** is applied globally via the `catppuccin.homeModules.catppuccin` shared module — except Kitty, which has `catppuccin.kitty.enable = false` and instead derives its colors live from whatever color scheme Caelestia Shell has active (see below). hyprlock, Rofi and Starship still use the static Catppuccin Mocha palette.
- **Caelestia Shell** (`modules/home/caelestia.nix`, flake input `caelestia-shell`) is a quickshell/Qt6 desktop shell that replaces Waybar, SwayNC, wlogout, and part of Rofi/hyprpicker (bar, launcher, dashboard, notifications, color picker, session menu). Integrated via its own home-manager module (`inputs.caelestia-shell.homeManagerModules.default`), not a from-scratch config.
- **Theme sync** (`modules/home/theme-sync.nix`): Caelestia's bundled "catppuccin" scheme uses different hex values than the real Catppuccin palette used elsewhere (two independent implementations sharing only names). Rather than reconciling them, Kitty consumes Caelestia's built-in pywal-style templating system: a template with `{{ colorName.hex }}` placeholders renders to `~/.local/state/caelestia/theme/kitty-colors.conf` on every `caelestia scheme set`, and a `theme.postHook` reloads Kitty live via its remote-control socket. This makes Kitty track whichever of Caelestia's ~13 bundled schemes is active, not just Catppuccin.
- **Wallpapers** (`modules/home/wallpapers.nix`): idempotently sparse-clones theme-matching wallpaper folders from `yukazakiri/themed-wallpapers` into `~/Pictures/Wallpapers/<theme>/` on first activation, without touching the existing animated `fondo.gif` (rendered via `mpvpaper`, which requires `background.wallpaperEnabled = false` in Caelestia's settings so its own background layer doesn't paint over it).
- **Window management stays in Hyprland**: Caelestia does not manage windows at all — it only exposes a per-window action popout in the bar (float/tile, pin, kill, move-to-workspace) for whatever window is currently focused. Alt-tab, mouse drag/resize for floating windows, centering, pin, and the scratchpad are all plain Hyprland binds in `modules/home/hyprland.nix` (`bindm`, `ALT, Tab` cyclenext, `togglespecialworkspace`). No window rules (`windowrule`) are declared: since Hyprland 0.55 that hyprlang syntax is deprecated in favor of Lua, and `configType` here is all-or-nothing (hyprlang or Lua for the whole file) — not worth a full config migration for cosmetic dialog rules.
- **nix-ld** (`modules/system/ai-helper.nix`) provides a broad set of runtime libraries so self-updating AI binaries (Claude Code, Codex, Kiro CLI, OpenCode) work without patching.
- **kiro-gateway** (`modules/home/kiro-gateway.nix`) auto-starts a community proxy (`Jwadow/kiro-gateway`) that exposes Kiro's models as an OpenAI/Anthropic-compatible API for opencode. Deliberately kept **out of the Nix store**: the cloned repo, its Python venv, and secrets (`.env` with `PROXY_API_KEY`) live in `~/dev/shared/kiro-gateway/`, and opencode's `~/.config/opencode/config.json` (provider `kiro` → `http://127.0.0.1:8000/v1`) is hand-edited too — adding/removing a model is a JSON edit, no rebuild. The Nix module contributes only a `systemd.user.services.kiro-gateway` unit with `ConditionPathExists` on the venv's python, so if the out-of-Nix bootstrap is ever deleted, the service just doesn't start instead of breaking `hm-switch`. No `LD_LIBRARY_PATH` override is needed for the venv's compiled wheels (tiktoken, pydantic-core, uvloop): nix-ld already exports `NIX_LD`/`NIX_LD_LIBRARY_PATH` globally via PAM, and `systemd --user` inherits them (confirmed with `systemctl --user show-environment`). Credentials source is Kiro IDE's token (`~/.aws/sso/cache/kiro-auth-token.json`, `KIRO_CREDS_FILE` in `.env`) — no `kiro-cli login` required; the gateway self-refreshes via the stored `refreshToken`. To remove entirely: drop the import line in `home.nix` and `rm -rf ~/dev/shared/kiro-gateway ~/.config/opencode`. Full bootstrap/usage steps: README.md, section "Kiro Gateway + opencode".
- **opencode is dual-installed on purpose**: the Nix package (`home.nix`, `home.packages`) is the reproducible fallback, but the primary binary is the standalone self-updating one at `~/.opencode/bin/opencode` (installed via `opencode upgrade --method curl` / `curl -fsSL https://opencode.ai/install | bash`), which `modules/home/zsh.nix`'s `PATH` export puts first — `opencode upgrade` can never work against the Nix copy since the store is read-only. Same pattern already used for `claude` (see the `claude()` wrapper function a few lines below in the same file).
- **3D/video creation stack** (`victus` only): `davinci-resolve`, `kdePackages.kdenlive`, `krita`, `gimp`, `inkscape`, `ffmpeg-full`, plus `blender` (CPU-only fallback) in `home.nix`; `hardware.nvidia.prime.offload.enableOffloadCmd = true` in `hosts/victus/default.nix` (provides the `nvidia-offload <app>` wrapper); and the `resolve`/`blender-gpu`/`to-dnxhr`/`to-h264` shell functions in `modules/home/zsh.nix`. Chosen because this laptop has an NVIDIA RTX 4050 (6 GB VRAM) in PRIME offload — the one config where DaVinci Resolve is officially viable on Linux (it would not be on AMD-only hardware). The free Resolve build cannot import/export H.264/H.265 on Linux (a licensing limit, not a hardware one), hence the `to-dnxhr`/`to-h264` ffmpeg-based ingest/deliver helpers instead of paying for Resolve Studio. `natron` was considered as a free Fusion alternative but is marked `broken` in the current nixpkgs-unstable pin, so it's omitted. **Blender needed a second fix**: nixpkgs' `blender` is compiled with `WITH_CYCLES_CUDA_BINARIES=FALSE`/`WITH_CYCLES_DEVICE_OPTIX=FALSE` (confirmed by inspecting its derivation) — Cycles has zero GPU backend, so Preferences only lists "None"/"CUDA" and CUDA finds no device even though the GPU is healthy (`nvidia-smi` sees it fine). Rebuilding with `nixpkgs.config.cudaSupport = true` was considered but rejected: it forces `cudaPackages.backendStdenv` (nvcc-based), has no binary cache since it's unfree, and would mean a 30-90+ min from-source rebuild plus several GB of CUDA toolkit. Instead, `modules/home/blender-gpu.nix` downloads the official blender.org standalone Linux build (version+SHA-256 pinned by hand, verified before extracting) to `~/.local/opt/blender` via an idempotent `home.activation` script (same idiom as `wallpapers.nix`'s sparse-clone) — same dual-install pattern as opencode/claude, standalone wins in PATH, Nix package stays as reproducible CPU-only fallback. That standalone binary still needed one more fix to actually see the GPU: its CUDA loader (CUEW) does `dlopen("libcuda.so")` at runtime, which NixOS doesn't expose on a standard library path (it lives at `/run/opengl-driver/lib`) — so `blender-gpu` sets `LD_LIBRARY_PATH="/run/opengl-driver/lib:$LD_LIBRARY_PATH"` in addition to `nvidia-offload`. Confirmed via `bpy`/Cycles device query: without the fix, OptiX/CUDA both report zero devices; with it, both correctly list the RTX 4050. **A third fix was needed for launching from rofi** (not just terminal): the plain `.desktop` files shipped by the `davinci-resolve`/`blender` packages have bare `Exec=davinci-resolve` / `Exec=blender %f` — no `nvidia-offload`, no XWayland, no `LD_LIBRARY_PATH` — because rofi's `drun` mode reads `.desktop` files directly, bypassing zsh (and its `initContent` PATH/functions) entirely. `modules/home/gpu-launchers.nix` overrides both via Home Manager's `xdg.desktopEntries` using the *same* desktop-file-id as the originals (`davinci-resolve`, `blender`): Home Manager installs generated desktop items with `lib.hiPrio`, so ours wins the profile-merge collision and replaces only that one file — the rest of each package (binary, icons, sibling `.desktop`s like `davinci-control-panels-setup`) is untouched (verified by inspecting the built `home-path` output). The Blender override hardcodes the absolute path `${config.home.homeDirectory}/.local/opt/blender/blender` rather than bare `blender`, because the graphical session's PATH (systemd/PAM-managed) never gets the `~/.local/opt/blender` prepend — that only exists inside zsh's `initContent`, so a bare `Exec=blender` there would've resolved back to the CPU-only Nix package. Verified by launching both with an artificially minimal `PATH` (`/etc/profiles/per-user/<user>/bin:/run/current-system/sw/bin`, no zsh involved) matching what rofi actually uses — DaVinci Resolve opened a real XWayland window, and Blender's device query still correctly listed OptiX/CUDA with the RTX 4050. Full rationale and daily-use commands: README.md, section "Edición 3D / Video".
- **Light/dark mode is global and drives the wallpaper too** (`modules/home/caelestia-scheme.nix`, `modules/home/theme-mode.nix`, README.md section "Modo claro / oscuro"): dark is Catppuccin Mocha, light is Catppuccin Latte. Caelestia's own dark/light switch (the panel toggle, `services/Colours.qml` → `Colours.setMode()`) only ever calls `caelestia scheme set -m <mode>`, keeping whatever name/flavour was already active — but in caelestia-cli's bundled Catppuccin data, `mocha` only has a `dark` mode and `latte` only has `light` (two separate flavours, not one palette with both modes), so that bare `-m light` throws before anything is applied. Since the scheme data lives in the read-only Nix store, it can't be merged there. Fix: `caelestia-scheme.nix` overrides `programs.caelestia.cli.package` with a `symlinkJoin` wrapper (`bin/caelestia` replaced by a script, everything else of the real package untouched) that intercepts *only* `scheme set` calls carrying `-m/--mode` with no `--flavour`/`--name`, and injects `--name catppuccin --flavour latte|mocha` accordingly — any other invocation (including `theme-sync.nix`'s bootstrap, which always passes an explicit flavour) passes through unmodified. This alone was enough for the terminal commands (`theme-light`/`theme-dark`/`theme-toggle`) and the `Super+Shift+T` bind, but **not** for the panel's own switch — a second, separate fix was needed for that (see the dedicated Troubleshooting entry below: `caelestia-shell`'s own binary bakes in an *unwrapped* copy of the CLI into its internal `PATH` via `makeWrapper`, independent of `programs.caelestia.cli.package`, and that copy always won inside the shell's own process). `caelestia-scheme.nix` also overrides `programs.caelestia.package` itself (rebuilding the upstream `with-cli` variant with our wrapped CLI substituted into its `caelestia-cli` build argument) so the panel resolves the same wrapper. `theme-mode.nix` also patches a second gap: `apply_gtk()` in caelestia-cli (`utils/theme.py`) hardcodes the GTK3/4 theme to `adw-gtk3-dark` regardless of mode (it only varies `color-scheme`/icon-theme via dconf) — so without a fix, Thunar would stay dark in light mode; the `theme.postHook` (`modules/home/caelestia.nix`) now also writes the correct `adw-gtk3`/`adw-gtk3-dark` dconf key based on `$SCHEME_MODE`, alongside the pre-existing kitty-reload behavior. Wallpaper follow-along uses the same postHook plus `set-wallpaper` (a real executable installed via `home.packages`, not a zsh function — it's also invoked from Hyprland's `Super+Shift+T` bind, and Hyprland's `exec` runs through `sh -c`, not zsh, so a zsh-only function wouldn't resolve there, same class of bug as the rofi `.desktop` issue above): it reads the persisted mode from `~/.local/state/caelestia/scheme.json` and relaunches `mpvpaper` with `fondo.gif` (dark) or `fondo-light.gif` (light), called both from `hyprland.nix`'s `exec-once` (so a fresh login already shows the right wallpaper) and from the postHook (so toggling mid-session updates it live). `fondo-light.gif` is fetched once via an idempotent, SHA-256-verified `home.activation` script in `wallpapers.nix` (same idiom as `blender-gpu.nix`) from a stable Wikimedia Commons URL — it's a generic placeholder (a cloud loop), not a thematic match for the hand-picked anime `fondo.gif`; dropping a personal file at that exact path (never overwritten if present) replaces it.
- **Pritunl VPN client is a system-level install, not home-manager** (`modules/system/pritunl.nix`, imported globally from `modules/system/core.nix` so every host gets it): the daemon that actually manages OpenVPN/WireGuard tunnels (`pritunl-client-service`) must run as root, so it can't live in a user profile. nixpkgs' `pritunl-client` package (unfree; `core.nix` already sets `allowUnfree = true`) already builds everything reproducibly from source — CLI (`pritunl-client`), the privileged daemon, and the Electron GUI (`pritunl-client-electron`, with its own `.desktop`+icons) — with openvpn/wireguard-tools already wrapped into the daemon's `PATH`, and it even ships a ready-made systemd unit (`lib/systemd/system/pritunl-client.service`). The module just does `systemd.packages = [ pkgs.pritunl-client ];` (installs the shipped unit) plus `systemd.services."pritunl-client".wantedBy = [ "multi-user.target" ];` (systemd.packages only installs a unit, it does not enable it — this line is what actually makes the daemon start at boot). This replaced an old, never-actually-used hack in `modules/home/zsh.nix`: a `pritunl()` function that shelled out to a manually-downloaded AppImage at `~/.local/bin/pritunl-client.AppImage`, a file that was never fetched (running `pritunl` only ever printed download instructions). `zsh.nix` now has a plain `shellAliases.pritunl = "pritunl-client-electron";` instead, just to keep the same muscle-memory command name pointed at the real GUI binary.

### Adding a new host

1. Create `hosts/<name>/default.nix` (import `core.nix`, `ai-helper.nix`, `display-manager.nix`; set `networking.hostName`).
2. Generate hardware config: `sudo nixos-generate-config --show-hardware-config > hosts/<name>/hardware-configuration.nix`.
3. The host becomes available automatically via `hostIfReady`.
4. Deploy: `sudo nixos-rebuild switch --flake .#<name>`.

### Git identity

Work repos inside `~/personal/` use `anthonydevxp@gmail.com`; everything else uses `antonio.zempoaltecatl@cargomovil.com`. This is wired via `git.includes` in `home.nix`.

## Troubleshooting / known issues

Real incidents hit while building the Caelestia integration, kept here so the
same root cause doesn't get re-diagnosed from scratch next time.

### `home-manager-anthony.service` fails: "existing file ... would be clobbered"

**Symptom:** `nix-switch` builds and switches the system generation fine, but
prints `warning: the following units failed: home-manager-anthony.service`,
with a log line like:
```
Existing file '/home/anthony/.config/gtk-4.0/gtk.css.hm-backup' would be clobbered by backing up '/home/anthony/.config/gtk-4.0/gtk.css'
```

**Cause:** two independent systems were both trying to own
`~/.config/gtk-4.0/gtk.css`: Home Manager's `gtk.gtk4.theme` option (which
symlinks that file to an immutable store path) and Caelestia's own bundled GTK
theming (`caelestia scheme set` → `apply_gtk()` in `caelestia-cli`, which
dynamically rewrites `gtk-3.0/gtk.css` **and** `gtk-4.0/gtk.css`, plus a
dedicated `thunar.css`, on every scheme change). Whichever ran second failed
because a `.hm-backup` from a previous partial run already existed. Also:
with `home.stateVersion` below `26.05`, `gtk.gtk4.theme` **defaults to**
`config.gtk.theme` (legacy behavior) even if never declared explicitly — just
deleting the line does not stop Home Manager from managing that file.

**Fix (`home.nix`):** set `gtk.gtk4.theme = null;` explicitly. Thunar is a
GTK3 app, so it never needed `gtk4.theme` for the original dark-bg/black-text
fix anyway — `gtk.theme = { name = "adw-gtk3-dark"; ... }` (GTK3-only) plus
Caelestia's own `apply_gtk()` already cover it.

**Prevention rule:** before adding a Home Manager option that manages a
dotfile under a path Caelestia also templates/writes to (GTK theme files,
kitty colors, anything under `~/.config/caelestia/templates/` targets), check
whether Caelestia's CLI (`src/caelestia/data/templates/`,
`src/caelestia/utils/theme.py` in the `caelestia-cli` source) already owns
that exact path. If it does, let Caelestia own it and keep Home Manager out
(same principle already applied to Kitty's colors in `theme-sync.nix`).

### Hyprland shows a config error banner: "windowrule ... invalid field ..."

**Symptom:** After adding window rules, `nix-switch`/`hm-switch` succeed with
no build errors, but Hyprland displays a persistent on-screen banner like:
```
Config error in file .../hyprhyprland.conf at line N: invalid field float: missing a value
```
(An earlier attempt at fixing this by renaming `windowrulev2` → `windowrule`
only changed the error from `"is deprecated"` to `"invalid field ..."` — it
did not actually fix anything.)

**Cause:** since Hyprland 0.55, window/layer rules are Lua-only
(`hl.window_rule({ match = {...}, ... })`); the old hyprlang string syntax
(`windowrule = rule, criteria:value`, `windowrulev2 = ...`) has no working
equivalent anymore, regardless of which of the two keyword names is used.
Home Manager's `wayland.windowManager.hyprland.configType` is all-or-nothing
per file (`"hyprlang"` → `hyprland.conf`, `"lua"` → `hyprland.lua`), so there
is no way to keep the rest of the config in hyprlang and only move window
rules to Lua without a full rewrite.

**Fix:** removed the `windowrule` block entirely from
`modules/home/hyprland.nix` rather than chase a bleeding-edge, still-shifting
Lua migration for a handful of cosmetic dialog rules. Window *navigation*
(`bindm` mouse drag/resize, `ALT, Tab` cyclenext + `bringactivetotop`,
`centerwindow`, `pin`, `togglespecialworkspace`) is unaffected — those are
plain `bind`/`bindm` keywords, still fully supported in hyprlang.

**Prevention rule:** before adding any `windowrule`/`windowrulev2`/`layerrule`
to this config, check the installed Hyprland version
(`hyprland --version` / `hyprctl version`) against the
[hyprland-wiki](https://github.com/hyprwm/hyprland-wiki) `Window-Rules.md` —
if it only shows Lua examples (`hl.window_rule(...)`), hyprlang string rules
are not a real option; either use `hyprctl configerrors` to confirm a rule
actually applies cleanly before committing it, or skip the rule.

### kiro-gateway "connects" but every chat request fails (500/502, "profileArn is required")

**Symptom:** `kiro-gateway.service` is `active (running)`, `/health` returns
`healthy`, and `/v1/models` even lists models correctly — but any real
request through opencode (`opencode run "..." -m kiro/claude-haiku-4.5`)
fails. Two distinct errors were hit in sequence with a Kiro IDE credentials
file (`KIRO_CREDS_FILE`, Option 1 in `.env.example`):
1. `502` + log line `ConnectError: [Errno -2] Name or service not known`.
2. After fixing (1): `Error: profileArn is required for this request.`

**Why `/health` and `/v1/models` don't catch this:** `/v1/models` returns a
**static, hardcoded model list** for `runtime.kiro.dev` endpoints (see
`kiro/account_manager.py`, log line `"Using static model list for
runtime.kiro.dev endpoint"`) — it never calls the real API, so it can't
reveal either of these problems. Only an actual chat request
(`/v1/chat/completions`) exercises the real upstream call.

**Cause of (1):** the auth manager auto-detects the API region from the
**SSO region** stored in the credentials (`region` field in
`kiro-auth-token.json`), and builds
`https://runtime.{region}.kiro.dev` from it. That field held `us-east-2` —
which is a valid *SSO/IAM Identity Center* region for this account, but
**`runtime.us-east-2.kiro.dev` does not exist in DNS** (confirmed: it fails
to resolve even from a plain `getent ahosts`, while `runtime.us-east-1.kiro.dev`
and the bare `kiro.dev` apex both resolve fine — so it's not a general
DNS/network problem, just that region has no runtime deployment). This is
the exact scenario `.env.example` describes under `KIRO_API_REGION`: "Your
SSO is in eu-west-1 but Q API only works in eu-central-1."

**Cause of (2):** `profileArn` auto-detection (`kiro/auth.py`) only reads it
from the **kiro-cli SQLite state table** (`state` key
`api.codewhisperer.profile`) — a data source that doesn't exist when using
Kiro IDE's plain JSON credentials file (`KIRO_CREDS_FILE`), which never
contains a `profileArn` field. With this credential source, auto-detection
silently has nothing to find.

**Fix (`~/dev/shared/kiro-gateway/.env`, NOT versioned in this repo — see
`modules/home/kiro-gateway.nix`):**
```
KIRO_API_REGION="us-east-1"
PROFILE_ARN="arn:aws:codewhisperer:us-east-1:<account-id>:profile/<profile-id>"
```
`PROFILE_ARN` was recovered from Kiro IDE's own runtime logs — it logs every
real API call it makes, including this field:
```bash
grep -o '"profileArn":"[^"]*"' ~/.config/Kiro/logs/*/window1/exthost/kiro.kiroAgent/q-client.log | sort -u
```
(Confirmed stable across multiple Kiro IDE sessions/log folders — it's tied
to the account, not the session.)

**Prevention rule:** when validating this integration (or after any Kiro
credential change), **don't stop at `/health` or `/v1/models`** — those can
report healthy while every real request 500s. Always test with an actual
completion, e.g. `opencode run "..." -m kiro/<model>`, and check
`journalctl --user -u kiro-gateway` for the specific error text if it fails.

### kiro-gateway: model `auto` (or `auto-kiro`) fails with "Invalid model ID or insufficient subscription level"

**Symptom:** requesting `kiro/auto-kiro` (the alias suggested by kiro-gateway's
own upstream docs/README as the friendly name for Kiro's "pick the best model
per task" mode) returns `HTTP 400` with the misleading message "Invalid model
ID or insufficient subscription level to use it." Looks like an account/plan
limitation, but it isn't.

**How this was actually diagnosed (worth repeating — don't trust the error
text at face value):** cross-checked against Kiro IDE's own runtime logs
(`~/.config/Kiro/logs/*/window1/exthost/kiro.kiroAgent/q-client.log`), which
record every real AWS SDK call the IDE makes, including full request/response
bodies. Two findings there disproved the "subscription" theory outright:
- `ListAvailableModelsCommand`'s live response includes
  `"defaultModel":{"modelId":"auto"}` — `auto` is this account's *default*
  model, not a locked/premium one.
- `grep -c '"modelId":"auto"'` across `GenerateAssistantResponseCommand`
  calls found **669 successful real uses** of literal `modelId: "auto"` by
  the IDE itself.

**Actual cause (a kiro-gateway bug, confirmed against the latest upstream
commit — `git fetch` + `git log HEAD..origin/main` showed zero pending
commits, so this isn't already fixed):** kiro-gateway ships
`MODEL_ALIASES = {"auto-kiro": "auto"}` (`kiro/config.py`) meant to translate
the friendly name to the real ID. That dict **is applied by `ModelResolver`
for the `/v1/models` listing endpoint only.** The function that actually
builds the chat-completion payload,
`get_model_id_for_kiro()` (`kiro/model_resolver.py:192`), is called with just
`HIDDEN_MODELS` (empty here) and never even receives `MODEL_ALIASES` — so
`auto-kiro` is normalized and passed straight through, unresolved, as the
literal string `"auto-kiro"` in the real request to Kiro's runtime API. Kiro
correctly rejects that (it's not a real model ID) with a generic
`INVALID_MODEL_ID` reason, which `kiro/kiro_errors.py:114` maps to the
misleading "insufficient subscription level" text for *any* invalid-ID case,
regardless of the real reason.

**Fix:** in `~/.config/opencode/config.json`, declare and request the model
under its **real, literal ID `auto`** — not `auto-kiro`. This fully
sidesteps the broken alias path (no gateway/venv patching needed):
```json
"models": { "auto": { "name": "Auto (Kiro elige y ahorra tokens)" } },
"model": "kiro/auto"
```
Confirmed working: `opencode run "..." -m kiro/auto` → real model response,
`HTTP 200` in `kgw-logs`.

**Also revealed by this investigation:** the gateway's `/v1/models` list is
**static** for `runtime.{region}.kiro.dev`-endpoint accounts (see
`kiro/account_manager.py`, comment `"New runtime endpoint does not provide
/ListAvailableModels (AWS limitation)"` — it never attempts a live call, just
serves the hardcoded `FALLBACK_MODELS` from `kiro/config.py`). Kiro IDE's own
live `ListAvailableModelsCommand` response for this exact account/profileArn
showed **more models than the gateway's static list** (`claude-sonnet-5`,
`claude-opus-4.8`) — so treat the gateway's model list as a lagging snapshot,
not ground truth; Kiro IDE's own logs are the authoritative source for what
an account currently has access to.

**Prevention rule:** if a future model/alias added to `opencode/config.json`
gets rejected as "invalid model ID," don't assume it's an entitlement
problem — check `~/.config/Kiro/logs/*/window1/exthost/kiro.kiroAgent/q-client.log`
for real `GenerateAssistantResponseCommand` calls using that exact model ID
first. If the IDE itself uses it successfully, the bug is almost certainly in
kiro-gateway's alias/normalization layer, not the account.

### Blender Preferences > System shows only "None"/"CUDA", and CUDA finds no device

**Symptom:** after installing the 3D/video stack, Blender's Preferences >
System doesn't even offer OptiX as an option — only "None" and "CUDA" — and
selecting CUDA reports no compatible device, even though `nvidia-smi` shows
the RTX 4050 healthy and fully visible to the driver.

**Cause (two separate, stacked problems — confirmed by direct inspection
on the live system, not guessed):**
1. **`pkgs.blender` from nixpkgs has zero Cycles GPU backend compiled in.**
   Dumping its `.drv` (`nix show-derivation`) shows
   `-DWITH_CYCLES_CUDA_BINARIES:BOOL=FALSE` and
   `-DWITH_CYCLES_DEVICE_OPTIX:BOOL=FALSE` in `cmakeFlags` — CPU-only Cycles,
   by design of the generic nixpkgs package (`cudaSupport ? config.cudaSupport`
   defaults to off). This is why OptiX doesn't even appear as an option.
2. **Even after switching to the official blender.org standalone build**
   (which does ship precompiled CUDA/OptiX kernels), a *second* issue
   remained: querying Cycles' device list via `bpy`
   (`prefs.get_devices_for_type('CUDA'/'OPTIX')`) returned empty lists, with
   `WARNING CUEW initialization failed: Error opening the library` in the
   log. Blender's CUDA loader (CUEW) does a runtime `dlopen("libcuda.so")`,
   but NixOS doesn't expose that library on any path a standalone
   (non-nix-ld-wrapped) binary would search by default — it lives at
   `/run/opengl-driver/lib/libcuda.so` (a symlink into the `nvidia-x11`
   store path), not a "standard" library directory.

**Fix:** don't try to make nixpkgs' `blender` GPU-capable (rebuilding with
`nixpkgs.config.cudaSupport = true` forces `cudaPackages.backendStdenv`,
has zero binary cache since it's unfree, and costs a 30-90+ min from-source
rebuild plus multi-GB CUDA toolkit download). Instead:
- `modules/home/blender-gpu.nix`: idempotent `home.activation` script
  (same idiom as `wallpapers.nix`) downloads the official
  `blender-X.Y.Z-linux-x64.tar.xz` from `download.blender.org`, verifies its
  SHA-256 against blender.org's own published `.sha256` file, and extracts
  it to `~/.local/opt/blender`. Version+hash are pinned by hand in that file
  (no silent "latest").
- `modules/home/zsh.nix`: `$HOME/.local/opt/blender` is prepended to `PATH`
  (same dual-install pattern as opencode/claude — standalone wins, Nix
  `blender` package in `home.nix` stays as the CPU-only reproducible
  fallback).
- The `blender-gpu` shell function sets
  `LD_LIBRARY_PATH="/run/opengl-driver/lib:$LD_LIBRARY_PATH"` in addition to
  `nvidia-offload`, so CUEW's `dlopen` actually finds `libcuda.so`.

**Verified fix works:** ran a headless Cycles device query
(`blender --background --python-expr "..."` calling
`prefs.get_devices_for_type()`) with and without the `LD_LIBRARY_PATH` fix —
without it, both OPTIX and CUDA report `[]`; with it, both correctly list
`('NVIDIA GeForce RTX 4050 Laptop GPU', 'OPTIX'/'CUDA')`.

**Prevention rule:** for any future GPU-accelerated app added to this stack,
don't assume "nixpkgs package exists" implies "GPU backend compiled in" —
check the package's actual `cmakeFlags`/build options
(`nix show-derivation nixpkgs#<pkg> | grep -i <backend>`) before debugging
the driver/hardware. And for any *standalone* (non-Nix, non-FHS-wrapped)
binary that dlopens NVIDIA libraries at runtime, remember NixOS keeps them at
`/run/opengl-driver/lib`, not a path a generic Linux binary would search by
default.

### Caelestia's own light/dark switch in the panel would fail with "does not have a light mode" — and then, after fixing that, still didn't work

**Symptom 1 (would have happened without the fix below — caught during
design, by reading caelestia-cli's source before shipping, not from a live
failure):** toggling the dark/light switch inside Caelestia's own settings
panel (WallpaperAndStyle page) throws a critical notification like
`"catppuccin mocha" does not have a light mode` instead of switching to a
light theme, and nothing gets re-themed.

**Cause 1:** the panel's switch (`services/Colours.qml`, `setMode()`) calls
`Quickshell.execDetached(["caelestia", "scheme", "set", "--notify", "-m",
mode])` — it only ever changes `mode`, keeping whatever `name`/`flavour` is
currently active. That's fine for schemes where one flavour has both a dark
and a light variant, but caelestia-cli's bundled Catppuccin data
(`data/schemes/catppuccin/{mocha,latte}/`) ships mocha with **only** a `dark`
mode and latte with **only** a `light` mode — they're two separate flavours,
not one palette with two modes. `Scheme.mode`'s setter
(`caelestia/utils/scheme.py`) checks the requested mode against
`get_scheme_modes(name, flavour)` and raises `ValueError` immediately if it's
not available for the *current* flavour — so a bare `-m light` while mocha is
active fails before `apply_colours()` (and therefore the `postHook`) ever
runs. The scheme data lives under `cli_data_dir / "schemes"`, inside the
read-only Nix store (`caelestia/utils/paths.py`), so there's no way to add a
"mocha-with-a-light-variant" entry there to route around it.

**Fix 1:** `modules/home/caelestia-scheme.nix` overrides
`programs.caelestia.cli.package` with a `pkgs.symlinkJoin` over the real CLI
package, whose `postBuild` replaces just `bin/caelestia` with a small bash
wrapper (everything else — fish completions, etc. — stays symlinked from the
original). The wrapper inspects argv only when it sees `scheme set`: if
`-m/--mode` is present and neither `-f/--flavour` nor `-n/--name` was also
passed (exactly the panel's call shape, and also matched by the plain
`theme-light`/`theme-dark` commands and the `Super+Shift+T` bind), it appends
`--name catppuccin --flavour latte` (for `light`) or `--flavour mocha` (for
`dark`) before `exec`-ing the real binary. Any call that already specifies a
flavour/name (e.g. `theme-sync.nix`'s bootstrap:
`--name catppuccin --flavour mocha --mode dark`) is passed through byte-for-byte
untouched.

**Verified 1:** built the wrapper (`nix build
.#homeConfigurations.anthony.activationPackage`) and exercised it directly
against a stub binary standing in for the real CLI, covering: the panel's
exact call shape for both `light` and `dark`, the `--mode=value` form, a
fully-explicit passthrough call, an unrelated subcommand (`wallpaper set`),
and a call that already sets `--flavour` to something else while also passing
`-m` (must NOT be overridden). All six produced the expected final argv.

**Symptom 2 (a real live failure, reported after Fix 1 was already shipped
and working from the terminal and the `Super+Shift+T` bind):** the terminal
commands (`theme-light`/`theme-dark`) and the Hyprland keybind correctly
switched Mocha↔Latte, but the panel's own dark-theme toggle still did
nothing when clicked.

**Cause 2:** `programs.caelestia.cli.package` only controls which `caelestia`
gets installed into `home.packages` (i.e. what a fresh terminal, or
Hyprland's `exec` via `sh -c`, resolve via the general profile `PATH` at
`/etc/profiles/per-user/<user>/bin`). It does **not** change what the
*shell's own binary* uses internally. `caelestia-shell`'s "with-cli" build
(`caelestia-shell.override { withCli = true; }`, the module's actual default
for `programs.caelestia.package`, per `hm-module.nix`) compiles with its own
`caelestia-cli` argument added to `runtimeDeps`, and its `postInstall` runs
`makeWrapper ${quickshell}/bin/qs $out/bin/caelestia-shell --prefix PATH :
"${lib.makeBinPath runtimeDeps}" ...` (`nix/default.nix` in the
`caelestia-shell` source) — baking an **unwrapped** copy of the CLI directly
into the shell binary's own `PATH`, upstream of (and unrelated to) our
override. A `--prefix PATH` entry is prepended ahead of whatever `PATH` the
process inherits, so when the panel calls `Quickshell.execDetached(["caelestia",
...])` from *inside* that already-running process, it always resolved the
baked-in raw CLI first — confirmed live by diffing the running
`caelestia-shell` process's `/proc/<pid>/environ` `PATH` entries against
`which caelestia`: the raw CLI's store path appeared before
`/etc/profiles/per-user/<user>/bin`. This is why the terminal and the bind
(which never go through that baked-in prefix) already worked while the panel
didn't — the same "two independent PATHs" class of bug as the
rofi/`.desktop` issue in `modules/home/gpu-launchers.nix`, but one layer
deeper (baked into a compiled wrapper instead of a `.desktop` file).

**Fix 2:** `caelestia-scheme.nix` also overrides `programs.caelestia.package`
itself, rebuilding the same upstream `with-cli` variant via
`inputs.caelestia-shell.packages.${pkgs.system}.caelestia-shell.override {
withCli = true; caelestia-cli = wrappedCli; }` — substituting our Fix-1
wrapper into the exact build argument upstream bakes into
`runtimeDeps`/`--prefix PATH`, instead of trying to patch anything after the
fact. Since `caelestia-cli` is a regular `callPackage` argument, `.override`
can replace it even though the flake's own `flake.nix` already passed an
explicit value for it at the original call site.

**Verified 2:** rebuilt (`nix build
.#homeConfigurations.anthony.activationPackage`) and inspected the compiled
`.caelestia-shell-wrapped` binary directly (`strings ... | grep prefix.*PATH`)
— the baked-in `PATH` list now ends with our
`caelestia-cli-catppuccin-mode-wrapper/bin` instead of the raw
`caelestia-cli-<hash>/bin`, and `readlink -f` on `bin/caelestia` inside that
directory resolves to the Fix-1 wrapper script.

**Prevention rule:** when a Home Manager module exposes both a `package`
option (the app itself) and a `cli.package`/similar sub-option (a tool the
app also shells out to), don't assume overriding the sub-option is enough —
check whether the main package's own build **also** bundles that tool
directly (grep the upstream package expression for `makeWrapper.*--prefix
PATH` and see whether the sub-tool's derivation is one of the inputs). If it
does, the sub-option override only affects call sites that resolve the tool
via the general profile `PATH` (terminal, Hyprland `exec`) — anything that
runs *inside* the main package's own wrapped process needs the main
`package` overridden too, with the sub-tool substituted into the same build
argument upstream already uses to bake it in.

### kitty doesn't repaint after a scheme/mode change — open windows stay stale, and so do brand-new tabs

**Symptom:** switching mode (`theme-light`/`theme-dark`, the keybind, or the
panel switch) correctly re-themes everything else, but kitty windows already
open keep the old colors (e.g. light text on a light background, or a fully
light terminal after switching back to dark) — and **opening a new tab in an
existing kitty window still gets the stale colors**, not the new scheme.

**Cause:** `modules/home/kitty.nix` sets `listen_on = "unix:/tmp/kitty"`, but
kitty **appends its own PID** to that path — the real control socket is
`/tmp/kitty-<PID>` (confirmed: `ls /tmp/kitty*` → `/tmp/kitty-39832`, one per
running kitty process). The `theme.postHook` (`modules/home/caelestia.nix`)
was reloading colors against the literal, unsuffixed `unix:/tmp/kitty`, which
never exists:
```
Error: Failed to connect to unix:/tmp/kitty ... connect: no such file or directory
```
The postHook's `2>/dev/null || true` silently swallowed this every time, so
`kitty @ set-colors` never actually ran. This explains both halves of the
symptom: `-a` (repaint all windows) never reached kitty, and `-c`
(`--configured`, which updates the in-memory template new tabs/windows are
created from) never ran either — so a new tab was never stale by accident, it
was inheriting colors that were never updated in the first place. (A brand
new kitty **OS window** happens to re-read the `include` file from disk on
startup, which is why the bug could look intermittent.)

**Fix:** the postHook now loops over the real sockets instead of assuming one
fixed path:
```sh
for sock in /tmp/kitty-*; do
  [ -S "$sock" ] || continue
  kitty @ --to "unix:$sock" set-colors -a -c \
    "$HOME/.local/state/caelestia/theme/kitty-colors.conf" 2>/dev/null || true
done
```
This reaches every running kitty instance/window (`-a`) and also updates the
configured colors new tabs inherit (`-c`).

**Verified:** ran the exact loop against the live socket both before and
after the fix — before, `kitty @ --to unix:/tmp/kitty ...` errored with "no
such file or directory"; the corrected loop found `/tmp/kitty-39832` and
`set-colors` returned success with no error output.

**Prevention rule:** any script that talks to kitty's remote-control socket
must never hardcode `listen_on`'s configured value literally — kitty suffixes
it with the PID at runtime. Glob for the real socket (`/tmp/kitty-*`, matching
whatever prefix `listen_on` uses) and check `[ -S "$sock" ]`, and don't trust
`2>/dev/null || true` to mean "it worked" — that pattern hid this exact bug
for an entire release. If a postHook/script silently no-ops, drop the
`2>/dev/null` temporarily and rerun manually to see the real error.
