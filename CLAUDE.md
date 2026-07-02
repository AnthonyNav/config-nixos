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
- **nix-ld** (`modules/system/ai-helper.nix`) provides a broad set of runtime libraries so self-updating AI binaries (Claude Code, Codex, Kiro CLI, OpenCode) work without patching.

### Adding a new host

1. Create `hosts/<name>/default.nix` (import `core.nix`, `ai-helper.nix`, `display-manager.nix`; set `networking.hostName`).
2. Generate hardware config: `sudo nixos-generate-config --show-hardware-config > hosts/<name>/hardware-configuration.nix`.
3. The host becomes available automatically via `hostIfReady`.
4. Deploy: `sudo nixos-rebuild switch --flake .#<name>`.

### Git identity

Work repos inside `~/personal/` use `anthonydevxp@gmail.com`; everything else uses `antonio.zempoaltecatl@cargomovil.com`. This is wired via `git.includes` in `home.nix`.
