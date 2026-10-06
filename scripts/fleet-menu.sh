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
    fleet-ui "$action"
    ;;
  doctor)
    run_and_hold fleet-ui doctor
    ;;
  fleet-info)
    run_and_hold fleet-info --json
    ;;
  identity-doctor)
    run_and_hold identity-doctor
    ;;
  ai-doctor)
    run_and_hold ai-doctor
    ;;
  nix-status)
    run_and_hold nix-status
    ;;
esac
