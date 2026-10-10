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
  move-mode
  resize-mode
  resize-step <left|right|up|down>
  mode-exit
  capture-menu | record-menu | media-menu
  screenshot <area|window|screen> [--clipboard|--file auto] [--region X,Y,W,H]
  record <start|status|stop|probe> [options]
  edit <copy|paste|cut|undo|redo|select-all|save|find|open|new|new-tab|close|quit|location|reload>
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
  menu|capture-menu|record-menu|media-menu)
    section=main
    case "$action" in capture-menu) section=capture ;; record-menu) section=record ;; media-menu) section=combined ;; esac
    target="$(hyprctl -j activewindow | jq -r '.address // empty')"
    selection="$(mktemp)"
    chmod 600 "$selection"
    trap 'rm -f "$selection"' EXIT
    kitty --class fleet-menu --title "Fleet menu" -e fleet-catalog menu --section "$section" --selection "$selection"
    if [ -n "$target" ] && [ "$target" != "0x0" ]; then
      hyprctl dispatch focuswindow "address:$target" >/dev/null || die "original window is no longer available"
    fi
    mapfile -t selected < <(fleet-catalog selection "$selection")
    if [ "${#selected[@]}" -gt 0 ]; then
      "$0" "${selected[@]}"
    fi
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
  move-mode|resize|resize-mode)
    mode=resize
    [ "$action" != move-mode ] || mode=move
    fleet-mode-indicator start "$mode" >/dev/null 2>&1 &
    indicator_pid=$!
    ready=0
    for _ in $(seq 1 50); do
      if ! kill -0 "$indicator_pid" 2>/dev/null; then break; fi
      if fleet-mode-indicator ready --pid "$indicator_pid"; then ready=1; break; fi
      sleep 0.1
    done
    [ "$ready" = 1 ] || die "mode indicator unavailable; submap was not entered"
    hyprctl dispatch submap "fleet-$mode" || { fleet-mode-indicator stop; exit 1; }
    ;;
  mode-exit)
    hyprctl dispatch submap reset
    fleet-mode-indicator stop
    ;;
  resize-step)
    case "${1:-}" in
      left) delta='-50 0' ;; right) delta='50 0' ;; up) delta='0 -50' ;; down) delta='0 50' ;;
      *) die "resize-step requires a direction" ;;
    esac
    hyprctl dispatch resizeactive "$delta"
    ;;
  screenshot|record)
    exec fleet-media --platform linux "$action" "$@"
    ;;
  edit)
    edit_action="${1:-}"
    window="$(hyprctl -j activewindow)"
    app="$(jq -r '.class // empty' <<<"$window")"
    target="$(jq -r '.address // empty' <<<"$window")"
    modifier=CTRL
    case "$app" in
      firefox|firefox-esr|org.mozilla.firefox|thunar|Thunar|dbgate|DbGate) ;;
      code|Code) modifier=SUPER ;;
      kitty)
        case "$edit_action" in
          copy|paste) modifier='CTRL SHIFT' ;;
          quit) modifier='CTRL SHIFT' ;;
          *) die "terminal action is reserved; use its native controls" ;;
        esac ;;
      *) die "application has no verified Fleet editing adapter" ;;
    esac
    case "$edit_action" in
      copy) key=c ;; paste) key=v ;; cut) key=x ;; undo) key=z ;;
      redo) key=z; modifier="$modifier SHIFT" ;; select-all) key=a ;;
      save) key=s ;; find) key=f ;; open) key=o ;; new) key=n ;;
      new-tab) key=t ;; close) key=w ;; quit) key=q ;; location) key=l ;; reload) key=r ;;
      *) die "invalid editing action" ;;
    esac
    hyprctl dispatch sendshortcut "$modifier,$key,address:$target"
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
