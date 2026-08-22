#!/usr/bin/env bash
set -euo pipefail

peers_json="${SYNCTHING_FLEET_PEERS_JSON:-[]}"
folders_json="${SYNCTHING_FLEET_FOLDERS_JSON:-[]}"
host_name="${SYNCTHING_FLEET_HOST:-}"
config_dir="${SYNCTHING_CONFIG_DIR:-$HOME/.config/syncthing}"
api_url="${SYNCTHING_API_URL:-http://127.0.0.1:8384}"
managed_device_prefix="${SYNCTHING_MANAGED_DEVICE_PREFIX:-fleet:}"
managed_folder_prefix="${SYNCTHING_MANAGED_FOLDER_PREFIX:-fleet-}"
mode="apply"

case "${1:-}" in
  "") ;;
  --check) mode="check" ;;
  --help|-h)
    cat <<'EOF'
Usage: syncthing-fleet-reconcile [--check]

Reconcile the declared Syncthing fleet over Tailscale.
EOF
    exit 0
    ;;
  *) echo "Unknown argument: $1" >&2; exit 64 ;;
esac

[[ -n "$host_name" ]] || { echo "SYNCTHING_FLEET_HOST is required." >&2; exit 64; }

api_key=""
api() { curl -fsS -H "X-API-Key: $api_key" "$@"; }

wait_for_syncthing() {
  for _ in $(seq 1 60); do
    if [[ -r "$config_dir/config.xml" ]]; then
      api_key="$(xmllint --xpath 'string(configuration/gui/apikey)' "$config_dir/config.xml" 2>/dev/null || true)"
      if [[ -n "$api_key" ]] && curl -fsS -H "X-API-Key: $api_key" "$api_url/rest/system/ping" 2>/dev/null | jq -e '.ping == "pong"' >/dev/null 2>&1; then
        return 0
      fi
    fi
    sleep 1
  done
  return 1
}

wait_for_tailscale() {
  local status=""
  for _ in $(seq 1 60); do
    if status="$(tailscale status --json 2>/dev/null)"; then printf '%s' "$status"; return 0; fi
    sleep 1
  done
  return 1
}

resolve_tailscale_ip() {
  local host="$1" status_json="$2"
  jq -r --arg host "$host" '[.Peer[]? | select((.HostName // "") == $host or (((.DNSName // "") | split(".")[0]) == $host)) | .TailscaleIPs[]? | select(contains(":") | not)][0] // empty' <<<"$status_json"
}

discover_device_id() {
  local host="$1" ip="$2" cert_file raw_id canonical_id
  cert_file="$(mktemp)"
  timeout 8s openssl s_client -connect "${ip}:22000" -servername "$host" -showcerts </dev/null 2>/dev/null \
    | awk '/-----BEGIN CERTIFICATE-----/ { capture = 1 } capture { print } /-----END CERTIFICATE-----/ { exit }' >"$cert_file" || true
  if ! openssl x509 -in "$cert_file" -noout >/dev/null 2>&1; then rm -f "$cert_file"; return 1; fi
  raw_id="$(openssl x509 -in "$cert_file" -outform der 2>/dev/null | openssl dgst -sha256 -binary | base32 | tr -d '=\n')"
  rm -f "$cert_file"
  [[ ${#raw_id} -eq 52 ]] || return 1
  canonical_id="$(api "$api_url/rest/svc/deviceid?id=$raw_id" | jq -er '.id')" || return 1
  printf '%s' "$canonical_id"
}

wait_for_syncthing || { echo "Syncthing API is not ready; leaving existing configuration unchanged." >&2; exit 75; }
tailscale_json="$(wait_for_tailscale)" || { echo "Tailscale is not ready; leaving existing configuration unchanged." >&2; exit 75; }

local_id="$(api "$api_url/rest/system/status" | jq -er '.myID')"
resolved_devices='[]'
while IFS= read -r peer; do
  [[ -n "$peer" ]] || continue
  ip="$(resolve_tailscale_ip "$peer" "$tailscale_json")"
  [[ -n "$ip" ]] || { echo "Tailscale peer '$peer' is unavailable." >&2; exit 75; }
  device_id="$(discover_device_id "$peer" "$ip")" || { echo "Could not derive Syncthing device ID for '$peer'." >&2; exit 75; }
  resolved_devices="$(jq -c --arg host "$peer" --arg ip "$ip" --arg id "$device_id" '. + [{host: $host, ip: $ip, id: $id}]' <<<"$resolved_devices")"
done < <(jq -r '.[]' <<<"$peers_json")

id_map="$(jq -cn --arg host "$host_name" --arg id "$local_id" '{($host): $id}')"
while IFS=$'\t' read -r peer _ip device_id; do
  id_map="$(jq -c --arg host "$peer" --arg id "$device_id" '. + {($host): $id}' <<<"$id_map")"
done < <(jq -r '.[] | [.host, .ip, .id] | @tsv' <<<"$resolved_devices")

while IFS= read -r folder; do
  while IFS= read -r participant; do
    [[ -n "$(jq -r --arg host "$participant" '.[$host] // empty' <<<"$id_map")" ]] || { echo "Folder references unresolved host '$participant'." >&2; exit 78; }
  done < <(jq -r '.hosts[]' <<<"$folder")
done < <(jq -c '.[]' <<<"$folders_json")

if [[ "$mode" == "check" ]]; then
  printf 'Syncthing fleet topology for %s\n' "$host_name"
  printf '  local: %s\n' "$local_id"
  jq -r '.[] | "  peer: \(.host) \(.ip) \(.id)"' <<<"$resolved_devices"
  jq -r '.[] | "  folder: \(.id) -> \(.path) [\(.hosts | join(", "))]"' <<<"$folders_json"
  exit 0
fi

device_default="$(api "$api_url/rest/config/defaults/device")"
while IFS=$'\t' read -r peer ip device_id; do
  payload="$(jq -c --arg id "$device_id" --arg name "${managed_device_prefix}${peer}" --arg address "tcp://${ip}:22000" '.deviceID = $id | .name = $name | .addresses = [$address] | .introducer = false | .autoAcceptFolders = false | .paused = false' <<<"$device_default")"
  api -X POST -H 'Content-Type: application/json' --data-binary "$payload" "$api_url/rest/config/devices" >/dev/null
done < <(jq -r '.[] | [.host, .ip, .id] | @tsv' <<<"$resolved_devices")

folder_default="$(api "$api_url/rest/config/defaults/folder")"
while IFS= read -r folder; do
  folder_id="$(jq -r '.id' <<<"$folder")"; label="$(jq -r '.label' <<<"$folder")"; path="$(jq -r '.path' <<<"$folder")"; folder_type="$(jq -r '.type' <<<"$folder")"
  mkdir -p "$path"
  devices="$(jq -c --argjson ids "$id_map" '[.hosts[] as $host | {deviceId: $ids[$host]}]' <<<"$folder")"
  payload="$(jq -c --arg id "$folder_id" --arg label "$label" --arg path "$path" --arg type "$folder_type" --argjson devices "$devices" '.id = $id | .label = $label | .path = $path | .type = $type | .devices = $devices | .paused = false' <<<"$folder_default")"
  api -X POST -H 'Content-Type: application/json' --data-binary "$payload" "$api_url/rest/config/folders" >/dev/null
done < <(jq -c '.[]' <<<"$folders_json")

desired_folder_ids="$(jq -c '[.[].id]' <<<"$folders_json")"
while IFS= read -r stale_id; do [[ -n "$stale_id" ]] && api -X DELETE "$api_url/rest/config/folders/$stale_id" >/dev/null; done < <(api "$api_url/rest/config/folders" | jq -r --arg prefix "$managed_folder_prefix" --argjson desired "$desired_folder_ids" '[ .[] | select(.id | startswith($prefix)) | .id ] - $desired | .[] | @uri')

desired_device_ids="$(jq -c '[.[].id]' <<<"$resolved_devices")"
while IFS= read -r stale_id; do [[ -n "$stale_id" ]] && api -X DELETE "$api_url/rest/config/devices/$stale_id" >/dev/null; done < <(api "$api_url/rest/config/devices" | jq -r --arg prefix "$managed_device_prefix" --argjson desired "$desired_device_ids" '[ .[] | select((.name // "") | startswith($prefix)) | .deviceID ] - $desired | .[] | @uri')

if api "$api_url/rest/config/restart-required" | jq -e '.requiresRestart' >/dev/null; then api -X POST "$api_url/rest/system/restart" >/dev/null; fi
printf 'Syncthing fleet reconciled: %s peer(s), %s managed folder(s).\n' "$(jq 'length' <<<"$resolved_devices")" "$(jq 'length' <<<"$folders_json")"
