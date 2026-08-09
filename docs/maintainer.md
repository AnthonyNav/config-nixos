# Maintainer Guide

## Architecture

`flake.nix` is the entry point for a single user, `anthony`, on three
workstations. Every workstation combines a NixOS host module with the shared
Home Manager profile and its own `hosts/<name>/home.nix` overlay.

| Host | Graphics | Home features |
|---|---|---|
| `victus` | AMD iGPU + NVIDIA PRIME | Creative suite, AMD monitoring |
| `desktop` | NVIDIA only | Creative suite, fixed three-monitor profile |
| `thinkpad` | Integrated graphics | Shared base profile only |

The installer ISO is not a workstation and does not import Home Manager.

## Commands

Validate every flake output without writing the lock file:

```sh
nix flake check --no-build --no-write-lock-file
```

Apply the complete configuration for the current host:

```sh
nix-switch
```

Apply only the Home Manager profile for the current host:

```sh
hm-switch
```

`hm-switch` selects `anthony@$(hostnamectl --static)`. It must not be changed
back to a generic profile because that would omit host-specific features.

## Non-Negotiable Invariants

- Caelestia owns files it dynamically renders, including GTK output, Kitty
  colors, and rendered template targets. Home Manager manages the Kitty
  template source, not the Caelestia-rendered output.
- Caelestia is the shell; Hyprland owns window navigation, scratchpad,
  mouse move/resize, and Alt-Tab. Verify syntax against the installed
  Hyprland before adding window or layer rules.
- Kiro Gateway intentionally remains outside the Nix store in
  `~/dev/shared/kiro-gateway/`. Its secret-bearing OpenCode config stays local.
  Validate it with a real completion, not only `/health` or `/v1/models`.
- Use Kiro model ID `auto`, never `auto-kiro`.
- The Catppuccin mode wrapper must override both the Caelestia CLI and shell
  package. The shell has its own wrapped internal PATH.
- Keep `catppuccin.hyprland.enable = false` while
  `wayland.windowManager.hyprland.configType = "hyprlang"`. Catppuccin emits
  a Lua `colors._var` block that Hyprlang rejects as unknown
  `colors:_var:_type` and `colors:_var:expr` options. Hyprland colors remain
  explicitly defined in `modules/home/hyprland.nix`.
- Kitty control sockets are PID-suffixed. Reload code must glob `/tmp/kitty-*`.
- Pritunl is a system module because its daemon needs root.
- The creative suite is imported only by NVIDIA hosts. The Blender launcher and
  desktop entry require `LD_LIBRARY_PATH=/run/opengl-driver/lib`.

## Host-Specific Changes

Keep generated `hardware-configuration.nix` files local to their host. Put
system hardware settings in `hosts/<name>/default.nix` and Home Manager
features in `hosts/<name>/home.nix`. A common module must never assume PRIME,
NVIDIA, a fixed monitor layout, or an AMD GPU.

When changing a shared profile, evaluate all hosts. When changing NVIDIA or
creative behavior, build both `victus` and `desktop`; PRIME and direct NVIDIA
are different runtime paths.

## OpenCode

OpenCode is installed from Nix and its version is pinned by `flake.lock`.
Shared skills and the RTK plugin are deployed by `modules/home/opencode.nix`.
The local `~/.config/opencode/config.json` is deliberately unmanaged because
it carries the Kiro credential. `opencode/config.example.json` is the
secret-free starting point for a new workstation. Restart OpenCode after a
skill or plugin change.

Claude Code remains installed as a secondary CLI. Its local permissions file
is not part of this repository.

## External Artifacts

Blender's CUDA/OptiX build and themed wallpapers are activation-time downloads.
They are explicit exceptions to Nix store reproducibility. Keep their version,
hash, owner, update procedure, and validation command documented when changing
them; do not let them become unpinned host-local dependencies.
