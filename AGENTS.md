# AGENTS.md

## Repo Shape

- This is a NixOS flake for one user: `username = "anthony"` in `flake.nix` is passed into NixOS and Home Manager via `specialArgs`.
- `home.nix` is the shared Home Manager profile for every host; `hosts/<name>/default.nix` holds machine-specific system config; `modules/home/` and `modules/system/` hold reusable modules.
- Home Manager is integrated into each `nixosSystem`; a full `nixos-rebuild switch` applies both system and user config. `homeConfigurations.anthony` exists for user-only switches.
- `hostIfReady` in `flake.nix` hides hosts that do not have `hardware-configuration.nix`; currently only `victus` is exposed by `nix flake show`.

## Commands

- Validate flake changes without switching: `nix flake check --no-write-lock-file`.
- Inspect outputs: `nix flake show --no-write-lock-file`.
- Full switch on the current machine: `nix-switch` from `modules/home/zsh.nix`.
- Explicit full switch: `sudo nixos-rebuild switch --flake .#victus`.
- If newly added files are not tracked by git yet, use `path:`: `sudo nixos-rebuild switch --flake "path:$PWD#victus"`.
- User-only switch: `hm-switch`, or `home-manager switch --flake "path:$HOME/nixos-config#anthony"`.
- There is no repo-local CI, pre-commit, formatter, or task runner config; use the flake commands above unless the user asks for an actual switch.

## Do Not Re-Diagnose These

- Caelestia owns dynamic theme files. Do not let Home Manager also manage paths Caelestia rewrites, especially GTK theme files, Kitty colors, or targets under `~/.config/caelestia/templates/`. `home.nix` intentionally sets `gtk.gtk4.theme = null`.
- Kitty does not use the static Catppuccin module. `modules/home/theme-sync.nix` lets Caelestia render `kitty-colors.conf`, and Kitty reloads it via Caelestia's `theme.postHook`.
- Caelestia is the shell, not the window manager. Window navigation, scratchpad, mouse move/resize, and Alt-Tab belong in Hyprland (`modules/home/hyprland.nix`).
- Do not add `windowrule`/`windowrulev2`/`layerrule` strings to the current Hyprland config unless you verify the installed Hyprland still accepts them; this repo deliberately avoids them because Hyprland 0.55 moved rules to Lua while `configType = "hyprlang"` is all-or-nothing.
- `kiro-gateway` is intentionally outside the Nix store at `~/dev/shared/kiro-gateway/`; this repo only declares a `systemd --user` service with `ConditionPathExists`. Secrets and `~/.config/opencode/config.json` stay outside Nix.
- For Kiro validation, `/health` and `/v1/models` are not enough; they can pass while chat fails. Test an actual completion such as `opencode run "responde solo con la palabra: funciona" -m kiro/claude-haiku-4.5` and inspect `kgw-logs` on failure.
- In opencode's Kiro config, use model ID `auto`, not `auto-kiro`; the gateway's alias path is broken for chat requests.
- Caelestia's Catppuccin data splits dark/light across *flavours* (mocha=dark only, latte=light only), not modes within one flavour. `caelestia scheme set -m <mode>` alone (what the panel's own switch sends) fails for Catppuccin without `modules/home/caelestia-scheme.nix`'s CLI wrapper, which injects the right `--flavour` when none was given. Don't try to fix this by editing scheme data — it lives in the read-only Nix store.
- That CLI wrapper alone isn't enough for the panel's own switch: `caelestia-shell`'s binary bakes an *unwrapped* copy of the CLI into its own internal `PATH` (`makeWrapper --prefix PATH`, independent of `programs.caelestia.cli.package`). `caelestia-scheme.nix` also overrides `programs.caelestia.package` itself (rebuilding the `with-cli` variant with our wrapped CLI substituted in) so `execDetached` calls from *inside* the shell process resolve the wrapper too.
- `theme-light`/`theme-dark`/`theme-toggle`/`set-wallpaper` (`modules/home/theme-mode.nix`) are real executables via `home.packages`, not zsh functions — same reasoning as the rofi/`.desktop` gotcha below: Hyprland's `Super+Shift+T` bind runs `exec` through `sh -c`, not zsh.
- kitty's remote-control socket is never the literal `listen_on` value — kitty suffixes it with its own PID (`/tmp/kitty-<PID>`). The `theme.postHook` in `modules/home/caelestia.nix` globs `/tmp/kitty-*` for this reason; don't reintroduce a hardcoded `unix:/tmp/kitty` path, and don't trust a `2>/dev/null || true` on a kitty reload to mean it worked.
- Pritunl is a system module (`modules/system/pritunl.nix`, imported from `core.nix` for every host), not a home-manager package — its daemon needs root. `zsh.nix`'s `pritunl` is just a `shellAliases` entry to the real `pritunl-client-electron` binary; the real CLI is `pritunl-client`.
- The 3D/video creative suite (`davinci-resolve`, `kdenlive`, `blender`, `krita`, `gimp`, `inkscape`, `ffmpeg-full`, `blender-gpu.nix`, `gpu-launchers.nix`) is not in `home.nix` — it's `modules/home/creative-suite.nix`, imported per-host as an opt-in home-manager module via `flake.nix`'s `mkHost extraHomeModules` param. Only `victus` passes it in. Don't add those packages back to shared `home.nix`; a GPU-less host would install them for nothing.

## GPU / Media Gotchas

- `victus` uses NVIDIA PRIME offload; `hosts/victus/default.nix` enables `nvidia-offload`, used by Resolve and Blender launchers.
- The nixpkgs `blender` package is intentionally only a reproducible CPU fallback. GPU Blender comes from `modules/home/blender-gpu.nix`, downloaded to `~/.local/opt/blender` with a pinned version and SHA-256.
- `blender-gpu` and the Blender `.desktop` override must include `LD_LIBRARY_PATH=/run/opengl-driver/lib` so Blender can `dlopen("libcuda.so")` on NixOS.
- Rofi/drun does not read zsh `PATH` or shell functions. Keep GPU desktop entries in `modules/home/gpu-launchers.nix` aligned with the terminal launchers in `modules/home/zsh.nix`.
- Free DaVinci Resolve on Linux cannot import/export H.264/H.265; use `to-dnxhr` for ingest and `to-h264` for delivery, or switch to `davinci-resolve-studio` if the user explicitly wants Studio.

## Existing Long-Form Context

- `README.md` has daily-use commands and user-facing setup notes.
- `CLAUDE.md` contains detailed troubleshooting history; preserve its hard-earned fixes when editing related modules.
