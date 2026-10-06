#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  fleet-ui <action> [argument]

Actions:
  terminal
  menu
  browser
  files
  orca
  lock
  focus <left|right|up|down>
  move <left|right|up|down>
  workspace <1-10>
  move-workspace <1-10>
  fullscreen
  toggle-floating
  resize
  shortcuts
  doctor
EOF
}

die() {
  printf 'fleet-ui: %s\n' "$*" >&2
  exit 1
}

have() {
  command -v "$1" >/dev/null 2>&1
}

direction() {
  case "$1" in
    left) printf l ;;
    right) printf r ;;
    up) printf u ;;
    down) printf d ;;
    *) die "invalid direction '$1'" ;;
  esac
}

valid_workspace() {
  case "$1" in
    1|2|3|4|5|6|7|8|9|10) return 0 ;;
    *) die "workspace must be between 1 and 10" ;;
  esac
}

action="${1:-}"
[ -n "$action" ] || {
  usage
  exit 2
}
shift || true

case "$action" in
  terminal)
    have kitty || die "kitty is not installed"
    kitty >/dev/null 2>&1 &
    ;;
  menu)
    have kitty || die "kitty is not installed"
    have fleet-menu || die "fleet-menu is not installed"
    kitty --class fleet-menu -e fleet-menu >/dev/null 2>&1 &
    ;;
  browser)
    have firefox || die "firefox is not installed"
    firefox >/dev/null 2>&1 &
    ;;
  files)
    have thunar || die "thunar is not installed"
    thunar "$HOME" >/dev/null 2>&1 &
    ;;
  orca)
    have orca-ide-gui || die "orca-ide-gui is not installed"
    orca-ide-gui >/dev/null 2>&1 &
    ;;
  lock)
    have caelestia || die "caelestia is not installed"
    caelestia shell lock lock
    ;;
  focus)
    dir="${1:-}"
    [ -n "$dir" ] || die "focus requires a direction"
    have hyprctl || die "hyprctl is not installed"
    hyprctl dispatch movefocus "$(direction "$dir")"
    ;;
  move)
    dir="${1:-}"
    [ -n "$dir" ] || die "move requires a direction"
    have hyprctl || die "hyprctl is not installed"
    hyprctl dispatch movewindow "$(direction "$dir")"
    ;;
  workspace)
    workspace="${1:-}"
    valid_workspace "$workspace"
    have hyprctl || die "hyprctl is not installed"
    hyprctl dispatch workspace "$workspace"
    ;;
  move-workspace)
    workspace="${1:-}"
    valid_workspace "$workspace"
    have hyprctl || die "hyprctl is not installed"
    hyprctl dispatch movetoworkspace "$workspace"
    ;;
  fullscreen)
    have hyprctl || die "hyprctl is not installed"
    hyprctl dispatch fullscreen 0
    ;;
  toggle-floating)
    have hyprctl || die "hyprctl is not installed"
    hyprctl dispatch togglefloating
    ;;
  resize)
    have hyprctl || die "hyprctl is not installed"
    hyprctl dispatch submap resize
    ;;
  shortcuts)
    have kitty || die "kitty is not installed"
    have fleet-shortcuts || die "fleet-shortcuts is not installed"
    kitty --class fleet-shortcuts -e fleet-shortcuts --hold >/dev/null 2>&1 &
    ;;
  doctor)
    fail=0
    for command_name in fleet-menu fleet-shortcuts hyprctl caelestia kitty; do
      if have "$command_name"; then
        printf 'OK   command: %s\n' "$command_name"
      else
        printf 'MISS command: %s\n' "$command_name"
        fail=1
      fi
    done
    exit "$fail"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    die "unknown action '$action' (run fleet-ui --help)"
    ;;
esac
