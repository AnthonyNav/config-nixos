#!/usr/bin/env bash
set -euo pipefail
unset LD_LIBRARY_PATH

printf 'Equipo: %s\n' "$(hostname)"
printf '\nMemoria y swap\n'
free -h
printf '\nServicios del sistema (consultar no los inicia)\n'
for unit in tailscaled syncthing syncthing-fleet-reconcile docker libvirtd restic-backups-fleet-personal; do
  state="$(systemctl show "$unit.service" --property=ActiveState --value 2>/dev/null || true)"
  load="$(systemctl show "$unit.service" --property=LoadState --value 2>/dev/null || true)"
  printf '  %-30s %s\n' "$unit" "${load:-unknown}/${state:-unknown}"
done
printf '\nServicios de sesión\n'
for unit in caelestia monitor-layout wlsunset; do
  state="$(systemctl --user show "$unit.service" --property=ActiveState --value 2>/dev/null || true)"
  printf '  %-30s %s\n' "$unit" "${state:-unknown}"
done
printf '\nCaelestia: memoria contabilizada y límites\n'
systemctl --user show caelestia.service --property=MemoryCurrent,MemorySwapCurrent,MemoryMax,MemorySwapMax 2>/dev/null || true
printf '\nUnidades fallidas\n'
systemctl --failed --no-pager || true
systemctl --user --failed --no-pager || true
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  printf '\nMonitores\n'
  hyprctl monitors 2>/dev/null || true
fi
printf '\nNo se consulta la API Docker ni la GPU; el diagnóstico no inicia cargas.\n'
