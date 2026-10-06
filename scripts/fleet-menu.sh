#!/usr/bin/env bash
set -euo pipefail

self_dir="$(cd "$(dirname "$0")" && pwd)"

resolve_command() {
  local name="$1"

  if [ "$name" = "fleet-ui" ] && [ -n "${FLEET_UI_BIN:-}" ] && [ -x "$FLEET_UI_BIN" ]; then
    printf '%s\n' "$FLEET_UI_BIN"
    return
  fi

  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return
  fi

  for candidate in \
    "$self_dir/$name" \
    "$HOME/.nix-profile/bin/$name" \
    "/etc/profiles/per-user/${USER:-}/bin/$name"; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return
    fi
  done

  printf 'fleet-menu: %s is not available\n' "$name" >&2
  return 1
}

run_and_hold() {
  status=0
  "$@" || status=$?
  printf '\nPress Enter to close...'
  read -r _
  return "$status"
}

choice="$(
  printf '%s\n' \
    $'Terminal\tterminal' \
    $'Browser\tbrowser' \
    $'Files\tfiles' \
    $'Orca\torca' \
    $'Shortcuts\tshortcuts' \
    $'Fleet interaction doctor\tdoctor' \
    $'Fleet info\tfleet-info' \
    $'Identity doctor\tidentity-doctor' \
    $'AI doctor\tai-doctor' \
    $'Nix status\tnix-status' |
    fzf --delimiter=$'\t' --with-nth=1 --prompt='Fleet > ' --height=100% --layout=reverse
)" || exit 0

action="${choice#*$'\t'}"

case "$action" in
  terminal|browser|files|orca|shortcuts)
    fleet_ui="$(resolve_command fleet-ui)"
    "$fleet_ui" "$action"
    ;;
  doctor)
    fleet_ui="$(resolve_command fleet-ui)"
    run_and_hold "$fleet_ui" doctor
    ;;
  fleet-info)
    command_path="$(resolve_command fleet-info)"
    run_and_hold "$command_path" --json
    ;;
  identity-doctor)
    command_path="$(resolve_command identity-doctor)"
    run_and_hold "$command_path"
    ;;
  ai-doctor)
    command_path="$(resolve_command ai-doctor)"
    run_and_hold "$command_path"
    ;;
  nix-status)
    command_path="$(resolve_command nix-status)"
    run_and_hold "$command_path"
    ;;
esac
