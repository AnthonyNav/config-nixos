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

darwin_app() {
  local app="$1"
  /usr/bin/open -Ra "$app" >/dev/null 2>&1
}

darwin_open_first() {
  local app
  for app in "$@"; do
    if darwin_app "$app"; then
      /usr/bin/open -a "$app"
      return 0
    fi
  done
  return 1
}

aerospace_bin() {
  if have aerospace; then
    command -v aerospace
    return
  fi
  if [ -x /opt/homebrew/bin/aerospace ]; then
    printf '%s\n' /opt/homebrew/bin/aerospace
    return
  fi
  die "AeroSpace CLI not found. Activate the Darwin interaction layer first."
}

direction_linux() {
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

platform="$(uname -s)"
action="${1:-}"
[ -n "$action" ] || {
  usage
  exit 2
}
shift || true

case "$action" in
  terminal)
    if [ "$platform" = Darwin ]; then
      if [ -x /Applications/kitty.app/Contents/MacOS/kitty ]; then
        /usr/bin/open -na kitty
      else
        /usr/bin/open -a Terminal
      fi
    else
      have kitty || die "kitty is not installed"
      kitty >/dev/null 2>&1 &
    fi
    ;;

  menu)
    if [ "$platform" = Darwin ]; then
      if [ -x /Applications/kitty.app/Contents/MacOS/kitty ]; then
        /Applications/kitty.app/Contents/MacOS/kitty -e fleet-menu >/dev/null 2>&1 &
      else
        /usr/bin/open -a Terminal
        die "kitty is required for the managed Fleet menu"
      fi
    else
      have kitty || die "kitty is not installed"
      kitty --class fleet-menu -e fleet-menu >/dev/null 2>&1 &
    fi
    ;;

  browser)
    if [ "$platform" = Darwin ]; then
      darwin_open_first Firefox Safari || die "no supported browser found"
    else
      have firefox || die "firefox is not installed"
      firefox >/dev/null 2>&1 &
    fi
    ;;

  files)
    if [ "$platform" = Darwin ]; then
      /usr/bin/open "$HOME"
    else
      have thunar || die "thunar is not installed"
      thunar "$HOME" >/dev/null 2>&1 &
    fi
    ;;

  orca)
    if [ "$platform" = Darwin ]; then
      darwin_open_first Orca || die "Orca is not installed"
    else
      have orca-ide-gui || die "orca-ide-gui is not installed"
      orca-ide-gui >/dev/null 2>&1 &
    fi
    ;;

  lock)
    if [ "$platform" = Darwin ]; then
      /usr/bin/open "hammerspoon://fleet-lock"
    else
      have caelestia || die "caelestia is not installed"
      caelestia shell lock lock
    fi
    ;;

  focus)
    direction="${1:-}"
    [ -n "$direction" ] || die "focus requires a direction"
    if [ "$platform" = Darwin ]; then
      "$(aerospace_bin)" focus "$direction"
    else
      have hyprctl || die "hyprctl is not installed"
      hyprctl dispatch movefocus "$(direction_linux "$direction")"
    fi
    ;;

  move)
    direction="${1:-}"
    [ -n "$direction" ] || die "move requires a direction"
    if [ "$platform" = Darwin ]; then
      "$(aerospace_bin)" move "$direction"
    else
      have hyprctl || die "hyprctl is not installed"
      hyprctl dispatch movewindow "$(direction_linux "$direction")"
    fi
    ;;

  workspace)
    workspace="${1:-}"
    valid_workspace "$workspace"
    if [ "$platform" = Darwin ]; then
      "$(aerospace_bin)" workspace "$workspace"
    else
      have hyprctl || die "hyprctl is not installed"
      hyprctl dispatch workspace "$workspace"
    fi
    ;;

  move-workspace)
    workspace="${1:-}"
    valid_workspace "$workspace"
    if [ "$platform" = Darwin ]; then
      "$(aerospace_bin)" move-node-to-workspace "$workspace"
      "$(aerospace_bin)" workspace "$workspace"
    else
      have hyprctl || die "hyprctl is not installed"
      hyprctl dispatch movetoworkspace "$workspace"
    fi
    ;;

  fullscreen)
    if [ "$platform" = Darwin ]; then
      "$(aerospace_bin)" fullscreen
    else
      have hyprctl || die "hyprctl is not installed"
      hyprctl dispatch fullscreen 0
    fi
    ;;

  shortcuts)
    if [ "$platform" = Darwin ]; then
      if [ -x /Applications/kitty.app/Contents/MacOS/kitty ]; then
        /Applications/kitty.app/Contents/MacOS/kitty -e sh -lc 'fleet-shortcuts; printf "\nPress Enter to close..."; read _' >/dev/null 2>&1 &
      else
        fleet-shortcuts
      fi
    else
      have kitty || die "kitty is not installed"
      kitty --class fleet-shortcuts -e sh -lc 'fleet-shortcuts; printf "\nPress Enter to close..."; read _' >/dev/null 2>&1 &
    fi
    ;;

  doctor)
    fail=0
    check_command() {
      if have "$1"; then
        printf 'OK   command: %s\n' "$1"
      else
        printf 'MISS command: %s\n' "$1"
        fail=1
      fi
    }

    printf 'Fleet interaction doctor (%s)\n' "$platform"
    check_command fleet-menu
    check_command fleet-shortcuts

    if [ "$platform" = Darwin ]; then
      for app in kitty Hammerspoon Karabiner-Elements AeroSpace; do
        if darwin_app "$app"; then
          printf 'OK   app: %s\n' "$app"
        else
          printf 'MISS app: %s\n' "$app"
          fail=1
        fi
      done
      if have aerospace || [ -x /opt/homebrew/bin/aerospace ]; then
        printf 'OK   command: aerospace\n'
      else
        printf 'MISS command: aerospace\n'
        fail=1
      fi
      if [ -f "$HOME/.config/karabiner/assets/complex_modifications/fleet-key.json" ]; then
        printf 'OK   Karabiner Fleet Key rule installed\n'
      else
        printf 'MISS Karabiner Fleet Key rule\n'
        fail=1
      fi
      if [ -f "$HOME/.hammerspoon/init.lua" ]; then
        printf 'OK   Hammerspoon Fleet bindings installed\n'
      else
        printf 'MISS Hammerspoon Fleet bindings\n'
        fail=1
      fi
      printf 'INFO macOS Accessibility/Input Monitoring permissions require manual approval.\n'
    else
      check_command hyprctl
      check_command caelestia
      check_command kitty
    fi
    exit "$fail"
    ;;

  -h|--help|help)
    usage
    ;;

  *)
    die "unknown action '$action' (run fleet-ui --help)"
    ;;
esac
