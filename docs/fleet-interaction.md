# Fleet keyboard interaction

This repository exposes one keyboard-oriented interaction contract across the
daily NixOS workstations and the registered Mac. The goal is muscle-memory
portability, not making macOS look or behave internally like NixOS.

## Ownership

The portable layer owns only logical commands:

- `fleet-ui`;
- `fleet-menu`;
- `fleet-shortcuts`.

Platform adapters implement those actions:

```text
Fleet action
    |
    +-- NixOS: Hyprland + Caelestia
    |
    +-- macOS: Hammerspoon + AeroSpace
```

The interaction layer does **not** own macOS wallpaper, Dock appearance, theme,
colors, icon layout or other visual personalization.

## Fleet Key

The physical `Caps Lock` key is the Fleet Key.

On NixOS, XKB maps Caps Lock to an additional Super key. The physical Super key
continues to work, so existing muscle memory and current Hyprland shortcuts are
preserved.

On macOS, the managed Karabiner Complex Modification maps Caps Lock to F18.
Hammerspoon treats held F18 as a modal Fleet key. F18 is used instead of a
four-modifier Hyper mapping so that `Fleet+Arrow` remains distinguishable from
`Fleet+Shift+Arrow`.

Run:

```sh
fleet-shortcuts
```

for the current portable contract.

Core mappings are:

| Intent | Shortcut |
| --- | --- |
| Terminal | Fleet + Enter |
| Fleet command palette | Fleet + Space |
| Browser | Fleet + B |
| Files | Fleet + T |
| Orca | Fleet + O |
| Lock | Fleet + L |
| Fullscreen | Fleet + F |
| Toggle floating/tiling | Fleet + E |
| Resize mode | Fleet + S |
| Shortcut help | Fleet + K |
| Focus window | Fleet + Arrow |
| Move window | Fleet + Shift + Arrow |
| Workspace 1-10 | Fleet + 1..9 / 0 |
| Move to workspace 1-10 | Fleet + Shift + 1..9 / 0 |

Platform-native application shortcuts remain native. In particular, macOS
Command shortcuts and NixOS-specific advanced Caelestia shortcuts are not
redefined by the portable contract.

## macOS adapter

nix-darwin owns the native applications:

- Kitty;
- Hammerspoon;
- Karabiner-Elements;
- AeroSpace.

Home Manager owns:

- `~/.hammerspoon/init.lua`;
- `~/.aerospace.toml`;
- the importable Karabiner Fleet Key Complex Modification.

The repository intentionally does not replace Karabiner's main configuration,
because it contains mutable/device-specific state.

### One-time manual permissions

macOS requires explicit user approval for privileged input/window automation.
After the reviewed configuration is activated:

1. Open Karabiner-Elements and approve its requested background/input
   permissions.
2. In Karabiner-Elements, import/enable **Fleet Key** from Complex
   Modifications.
3. Open Hammerspoon and grant Accessibility permission.
4. Open AeroSpace and grant Accessibility permission.
5. Reload Hammerspoon after permissions are granted.
6. Run:

```sh
fleet-ui doctor
```

Privacy permissions remain manual by design; the repository must not bypass
macOS consent controls.

## Keyboard defaults on macOS

nix-darwin configures only functional keyboard behavior:

- full keyboard UI navigation mode;
- initial key-repeat delay;
- key-repeat rate.

Visual macOS personalization stays user-owned.

## Linux adapter

Caps Lock becomes another Super key. Existing Hyprland mappings therefore
provide most of the Fleet contract without duplicating the window-manager
configuration.

Additional portable aliases provide:

- `Super/Caps + Space` -> Fleet menu;
- `Super/Caps + O` -> Orca;
- `Super/Caps + K` -> portable shortcut guide.

Existing physical Super shortcuts remain valid.

## CLI

Examples:

```sh
fleet-ui terminal
fleet-ui files
fleet-ui focus left
fleet-ui move right
fleet-ui workspace 3
fleet-ui move-workspace 4
fleet-ui fullscreen
fleet-ui toggle-floating
fleet-ui resize
fleet-ui doctor
```

The CLI is an intent-level interface. Scripts and future adapters should call
these actions rather than embedding Hyprland or AeroSpace commands in portable
code.

## Maintenance rules

- Do not add Darwin checks to portable interaction code.
- Do not add Hyprland/Caelestia dependencies to the common package.
- Platform-specific commands belong in the adapter/dispatcher branches.
- Preserve native macOS Command shortcuts.
- Preserve the physical Super key on Linux.
- Keep visual personalization outside this interaction layer.
- Changes to the Fleet contract should update `fleet-shortcuts` and this
  document together.
