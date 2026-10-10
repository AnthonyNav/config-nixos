#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: fleet-ui <action> [options]
macOS uses its native keyboard and window controls.

Actions:
  terminal | browser | files | orca
  screenshot <area|window|screen> [options]
  record <start|status|stop|probe> [options]
  shortcuts [--hold]
  doctor
EOF
}

open_first() {
  local app
  for app in "$@"; do
    if /usr/bin/open -Ra "$app" >/dev/null 2>&1; then
      /usr/bin/open -a "$app"
      return 0
    fi
  done
  printf 'fleet-ui: application not installed\n' >&2
  return 1
}

action="${1:-}"
shift || true
case "$action" in
  terminal)
    if [ -x /Applications/kitty.app/Contents/MacOS/kitty ]; then
      /usr/bin/open -na kitty
    else
      /usr/bin/open -a Terminal
    fi
    ;;
  browser) open_first Firefox Safari ;;
  files) /usr/bin/open "$HOME" ;;
  orca) open_first Orca ;;
  screenshot|record) exec fleet-media --platform darwin "$action" "$@" ;;
  shortcuts)
    if [ "$#" -gt 1 ] || { [ "$#" -eq 1 ] && [ "$1" != --hold ]; }; then
      printf 'fleet-shortcuts: expected --hold or no arguments\n' >&2
      exit 2
    fi
    cat <<'EOF'
macOS: controles nativos
Cmd+C/V/X       Copiar / pegar / cortar
Cmd+Z          Deshacer
Cmd+Shift+Z    Rehacer
Cmd+S/F        Guardar / buscar
Cmd+Tab        Cambiar de aplicación
Cmd+W          Cerrar ventana, documento o pestaña
Cmd+Q          Salir normalmente de la aplicación
Cmd+M          Minimizar
Ctrl+Cmd+Q     Bloquear la Mac
Cmd+Shift+3/4/5 Capturar pantalla / área / opciones de captura y grabación
Ctrl+C/Z/D     Controles habituales de terminal y SSH
Caps Lock y Option/AltGr mantienen su función.
Fleet no registra atajos ni administra ventanas en esta Mac.
Capturas/grabaciones por comando: fleet-ui screenshot / fleet-ui record.
EOF
    if [ "${1:-}" = --hold ] && [ -t 0 ]; then
      read -r -p 'Enter para salir… ' _fleet_native_answer
    fi
    ;;
  doctor)
    printf 'OK   macOS native keyboard/window controls selected\n'
    failed=0
    for app in Hammerspoon AeroSpace; do
      if /usr/bin/pgrep -x "$app" >/dev/null 2>&1; then
        printf 'WARN %s is running; close it to retain native controls\n' "$app"
        failed=1
      fi
    done
    fleet-media --platform darwin record status
    exit "$failed"
    ;;
  menu|capture-menu|record-menu|media-menu|move-mode|resize-mode|resize|focus|move|workspace|move-workspace|fullscreen|toggle-floating|resize-step|mode-exit|edit|lock)
    printf 'fleet-ui: Fleet keyboard/window actions are retired on macOS; use native controls\n' >&2
    exit 64
    ;;
  -h|--help|help) usage ;;
  '') usage; exit 2 ;;
  *) printf 'fleet-ui: unknown action (run fleet-ui --help)\n' >&2; exit 2 ;;
esac
