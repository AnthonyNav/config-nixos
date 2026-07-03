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
