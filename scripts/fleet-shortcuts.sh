cat <<'EOF'
Fleet keyboard contract

Fleet Key:
  NixOS   Caps Lock (also keeps the physical Super key)
  macOS   Caps Lock -> F18 -> Hammerspoon Fleet mode

Core actions:
  Fleet + Enter          Terminal
  Fleet + Space          Fleet menu
  Fleet + B              Browser
  Fleet + T              Files
  Fleet + O              Orca
  Fleet + L              Lock
  Fleet + F              Fullscreen
  Fleet + E              Toggle floating/tiling
  Fleet + S              Resize mode (arrows; Enter/Escape to exit)
  Fleet + K              This shortcut guide

Window navigation:
  Fleet + Arrow          Focus window
  Fleet + Shift + Arrow  Move window

Workspaces:
  Fleet + 1..9           Switch workspace
  Fleet + 0              Workspace 10
  Fleet + Shift + 1..9   Move window to workspace
  Fleet + Shift + 0      Move window to workspace 10

Platform-native shortcuts remain native:
  macOS Command shortcuts, Mission Control and application shortcuts are not remapped.
  NixOS keeps existing Caelestia/Hyprland aliases and advanced shortcuts.
EOF

if [ "${1:-}" = "--hold" ]; then
  printf '\nPress Enter to close...'
  read -r _
fi
