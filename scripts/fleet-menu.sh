self_dir="$(cd "$(dirname "$0")" && pwd)"

resolve_command() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return
  fi
  if [ -x "$self_dir/$name" ]; then
    printf '%s\n' "$self_dir/$name"
    return
  fi
  printf 'fleet-menu: %s is not available\n' "$name" >&2
  return 1
}

run_and_hold() {
  "$@"
  status=$?
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
    "$(resolve_command fleet-ui)" "$action"
    ;;
  doctor)
    run_and_hold "$(resolve_command fleet-ui)" doctor
    ;;
  fleet-info)
    run_and_hold "$(resolve_command fleet-info)" --json
    ;;
  identity-doctor)
    run_and_hold "$(resolve_command identity-doctor)"
    ;;
  ai-doctor)
    run_and_hold "$(resolve_command ai-doctor)"
    ;;
  nix-status)
    run_and_hold "$(resolve_command nix-status)"
    ;;
esac
