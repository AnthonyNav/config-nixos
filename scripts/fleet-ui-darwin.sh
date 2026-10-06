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
    if [ -x /Applications/kitty.app/Contents/MacOS/kitty ]; then
      /usr/bin/open -na kitty
    else
      /usr/bin/open -a Terminal
    fi
    ;;
  menu)
    darwin_app kitty || die "kitty is required for the managed Fleet menu"
    have fleet-menu || die "fleet-menu is not installed"
    /Applications/kitty.app/Contents/MacOS/kitty -e fleet-menu >/dev/null 2>&1 &
    ;;
  browser)
    darwin_open_first Firefox Safari || die "no supported browser found"
    ;;
  files)
    /usr/bin/open "$HOME"
    ;;
  orca)
    darwin_open_first Orca || die "Orca is not installed"
    ;;
  lock)
    /usr/bin/open "hammerspoon://fleet-lock"
    ;;
  focus)
    direction="${1:-}"
    [ -n "$direction" ] || die "focus requires a direction"
    "$(aerospace_bin)" focus "$direction"
    ;;
  move)
    direction="${1:-}"
    [ -n "$direction" ] || die "move requires a direction"
    "$(aerospace_bin)" move "$direction"
    ;;
  workspace)
    workspace="${1:-}"
    valid_workspace "$workspace"
    "$(aerospace_bin)" workspace "$workspace"
    ;;
  move-workspace)
    workspace="${1:-}"
    valid_workspace "$workspace"
    "$(aerospace_bin)" move-node-to-workspace "$workspace"
    "$(aerospace_bin)" workspace "$workspace"
    ;;
  fullscreen)
    "$(aerospace_bin)" fullscreen
    ;;
  toggle-floating)
    "$(aerospace_bin)" layout floating tiling
    ;;
  resize)
    "$(aerospace_bin)" mode resize
    ;;
  shortcuts)
    darwin_app kitty || die "kitty is required for the managed shortcut guide"
    have fleet-shortcuts || die "fleet-shortcuts is not installed"
    /Applications/kitty.app/Contents/MacOS/kitty -e fleet-shortcuts --hold >/dev/null 2>&1 &
    ;;
  doctor)
    fail=0
    for command_name in fleet-menu fleet-shortcuts; do
      if have "$command_name"; then
        printf 'OK   command: %s\n' "$command_name"
      else
        printf 'MISS command: %s\n' "$command_name"
        fail=1
      fi
    done
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
    exit "$fail"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    die "unknown action '$action' (run fleet-ui --help)"
    ;;
esac
