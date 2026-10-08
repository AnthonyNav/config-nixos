#!/usr/bin/env bash
set -euo pipefail
umask 077

peers_json="${SYNCTHING_FLEET_PEERS_JSON:-[]}"
folders_json="${SYNCTHING_FLEET_FOLDERS_JSON:-[]}"
legacy_folders_json="${SYNCTHING_FLEET_LEGACY_FOLDERS_JSON:-[]}"
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
api() { curl -fsS --connect-timeout 3 --max-time 15 -H "X-API-Key: $api_key" "$@"; }

wait_for_syncthing() {
  for _ in $(seq 1 60); do
    if [[ -r "$config_dir/config.xml" ]]; then
      api_key="$(xmllint --xpath 'string(configuration/gui/apikey)' "$config_dir/config.xml" 2>/dev/null || true)"
      if [[ -n "$api_key" ]] && api "$api_url/rest/system/ping" 2>/dev/null | jq -e '.ping == "pong"' >/dev/null 2>&1; then
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
    if status="$(tailscale status --json 2>/dev/null)" && jq -e '.BackendState == "Running"' <<<"$status" >/dev/null; then
      printf '%s' "$status"; return 0
    fi
    sleep 1
  done
  return 1
}

resolve_tailscale_peer() {
  local host="$1" status_json="$2"
  # LocalHostName may preserve capitals while MagicDNS always uses lowercase.
  jq -ce --arg host "$host" '[.Peer[]? | select(((.HostName // "") | ascii_downcase) == ($host | ascii_downcase) or (((.DNSName // "") | split(".")[0] // "" | ascii_downcase) == ($host | ascii_downcase)))]
    | if length > 1 then error("Ambiguous Tailscale peer") else .[0] // {} end' <<<"$status_json"
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

# Read both collections before discovery or mutation. Registered offline peers
# are valid participants, not obsolete devices to remove from the topology.
existing_devices="$(api "$api_url/rest/config/devices" | jq -ce 'if type == "array" then . else error("Expected devices array") end')" || { echo "Could not read Syncthing devices; leaving configuration unchanged." >&2; exit 75; }
existing_folders="$(api "$api_url/rest/config/folders" | jq -ce 'if type == "array" then . else error("Expected folders array") end')" || { echo "Could not read Syncthing folders; leaving configuration unchanged." >&2; exit 75; }
legacy_to_pause="$(jq -ce --argjson policies "$legacy_folders_json" '[ $policies[] as $policy | .[] | select(.id == $policy.id)
  | if .path == $policy.path or .path == ("~/" + $policy.relativePath) then . else error("Legacy folder ID/path mismatch; no changes applied") end
  | select(.paused != true)]' <<<"$existing_folders")" || exit 78
tailscale_json="$(wait_for_tailscale)" || { echo "Tailscale discovery deferred; reusing registered identities." >&2; tailscale_json='{}'; }

local_id="$(api "$api_url/rest/system/status" | jq -er '.myID')"
resolved_devices='[]'
deferred_peers='[]'
while IFS= read -r peer; do
  [[ -n "$peer" ]] || continue
  cached_id="$(jq -er --arg name "${managed_device_prefix}${peer}" 'map(select(.name == $name))
    | if length > 1 then error("Ambiguous registered device") else .[0].deviceID // "" end' <<<"$existing_devices")" || exit 78
  tailnet_peer="$(resolve_tailscale_peer "$peer" "$tailscale_json")" || exit 78
  ip="$(jq -r '[.TailscaleIPs[]? | select(test("^100\\.([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3})$"))
    | select((split(".") | map(tonumber)) as $ip | $ip[1] >= 64 and $ip[1] <= 127 and $ip[2] <= 255 and $ip[3] <= 255)][0] // empty' <<<"$tailnet_peer")"
  device_id=""
  if [[ -n "$ip" ]] && jq -e '.Online == true' <<<"$tailnet_peer" >/dev/null; then
    device_id="$(discover_device_id "$peer" "$ip")" || true
  fi
  if [[ -z "$device_id" ]]; then
    deferred_peers="$(jq -c --arg host "$peer" '. + [$host]' <<<"$deferred_peers")"
    device_id="$cached_id"
    [[ -n "$device_id" ]] || continue
  fi
  resolved_devices="$(jq -c --arg host "$peer" --arg ip "$ip" --arg id "$device_id" '. + [{host: $host, ip: $ip, id: $id}]' <<<"$resolved_devices")"
done < <(jq -r '.[]' <<<"$peers_json")

id_map="$(jq -cn --arg host "$host_name" --arg id "$local_id" '{($host): $id}')"
while IFS= read -r device; do
  peer="$(jq -r '.host' <<<"$device")"; device_id="$(jq -r '.id' <<<"$device")"
  id_map="$(jq -c --arg host "$peer" --arg id "$device_id" '. + {($host): $id}' <<<"$id_map")"
done < <(jq -c '.[]' <<<"$resolved_devices")

while IFS= read -r folder; do
  while IFS= read -r participant; do
    [[ "$participant" == "$host_name" ]] || jq -e --arg host "$participant" 'index($host) != null' <<<"$peers_json" >/dev/null || { echo "Folder references undeclared host '$participant'." >&2; exit 78; }
  done < <(jq -r '.hosts[]' <<<"$folder")
done < <(jq -c '.[]' <<<"$folders_json")

if [[ -n "${SYNCTHING_FLEET_IGNORE_HELPER:-}" ]]; then
  python3 "$SYNCTHING_FLEET_IGNORE_HELPER" --check
fi

if [[ "$mode" == "check" ]]; then
  printf 'Syncthing fleet topology for %s\n' "$host_name"
  printf '  local: %s\n' "$local_id"
  jq -r '.[] | "  peer: \(.host) \(.ip) \(.id)"' <<<"$resolved_devices"
  jq -r '.[] | "  folder: \(.id) -> \(.path) [\(.hosts | join(", "))]"' <<<"$folders_json"
  jq -r '.[] | "  discovery deferred: \(.)"' <<<"$deferred_peers"
  jq -r '.[] | "  legacy folder to pause: \(.id)"' <<<"$legacy_to_pause"
  exit 0
fi

# Read both collections before any mutation. Defaults are only for creation:
# POST replaces an existing object, whereas PATCH changes its supplied fields.
retired_device_ids="$(jq -c --arg prefix "$managed_device_prefix" --argjson peers "$peers_json" --argjson ids "$id_map" '[.[] | select((.name // "") | startswith($prefix))
  | (.name | ltrimstr($prefix)) as $host
  | select(($peers | index($host)) == null or ($ids[$host] != null and $ids[$host] != .deviceID)) | .deviceID]' <<<"$existing_devices")"
device_default="$(api "$api_url/rest/config/defaults/device" | jq -ce 'if type == "object" then . else error("Expected device defaults object") end')" || { echo "Could not read device defaults; leaving configuration unchanged." >&2; exit 75; }
folder_default="$(api "$api_url/rest/config/defaults/folder" | jq -ce 'if type == "object" then . else error("Expected folder defaults object") end')" || { echo "Could not read folder defaults; leaving configuration unchanged." >&2; exit 75; }
while IFS= read -r legacy; do
  legacy_id="$(jq -r '.id | @uri' <<<"$legacy")"
  backup="$(mktemp "$config_dir/fleet-paused-${legacy_id}.XXXXXX.json")"
  chmod 600 "$backup"
  printf '%s\n' "$legacy" >"$backup"
  api -X PATCH -H 'Content-Type: application/json' --data-binary '{"paused":true}' "$api_url/rest/config/folders/$legacy_id" >/dev/null
done < <(jq -c '.[]' <<<"$legacy_to_pause")
if [[ -n "${SYNCTHING_FLEET_IGNORE_HELPER:-}" ]]; then
  python3 "$SYNCTHING_FLEET_IGNORE_HELPER"
fi
while IFS= read -r device; do
  peer="$(jq -r '.host' <<<"$device")"; ip="$(jq -r '.ip' <<<"$device")"; device_id="$(jq -r '.id' <<<"$device")"
  payload="$(jq -cn --arg name "${managed_device_prefix}${peer}" --arg ip "$ip" '{name: $name, introducer: false, autoAcceptFolders: false}
    + if $ip == "" then {} else {addresses: ["tcp://" + $ip + ":22000"]} end')"
  existing="$(jq -c --arg id "$device_id" 'map(select(.deviceID == $id))[0] // null' <<<"$existing_devices")"
  if [[ "$existing" == "null" ]]; then
    payload="$(jq -c --arg id "$device_id" --argjson fields "$payload" '. + $fields + {deviceID: $id}' <<<"$device_default")"
    api -X POST -H 'Content-Type: application/json' --data-binary "$payload" "$api_url/rest/config/devices" >/dev/null
  elif ! jq -e --argjson fields "$payload" '. as $existing | $fields | to_entries | all(.[]; $existing[.key] == .value)' <<<"$existing" >/dev/null; then
    encoded_id="$(jq -rn --arg id "$device_id" '$id | @uri')"
    api -X PATCH -H 'Content-Type: application/json' --data-binary "$payload" "$api_url/rest/config/devices/$encoded_id" >/dev/null
  fi
done < <(jq -c '.[]' <<<"$resolved_devices")

while IFS= read -r folder; do
  folder_id="$(jq -r '.id' <<<"$folder")"; label="$(jq -r '.label' <<<"$folder")"; path="$(jq -r '.path' <<<"$folder")"; folder_type="$(jq -r '.type' <<<"$folder")"
  mkdir -p "$path"
  existing="$(jq -c --arg id "$folder_id" 'map(select(.id == $id))[0] // null' <<<"$existing_folders")"
  # Keep per-device fields and user-added shares. Only obsolete fleet shares
  # are removed; replacing the child array must not reset encryption options.
  obsolete="$(jq -c --arg prefix "$managed_device_prefix" --argjson hosts "$(jq '.hosts' <<<"$folder")" --argjson retired "$retired_device_ids" '$retired + [.[] | select((.name // "") | startswith($prefix)) | (.name | ltrimstr($prefix)) as $host | select(($hosts | index($host)) == null) | .deviceID]' <<<"$existing_devices")"
  devices="$(jq -c --argjson ids "$id_map" --argjson existing "$existing" --argjson managed "$obsolete" '
    [.hosts[] as $host | $ids[$host] | select(. != null)] as $desired
    | ($existing.devices // []) as $old
    | ([$desired[] as $id | ($old | map(select(.deviceId == $id))[0] // {deviceId: $id})]
      + [$old[] | .deviceId as $id | select(($desired | index($id)) == null and ($managed | index($id)) == null)])
    | sort_by(.deviceId)' <<<"$folder")"
  payload="$(jq -cn --arg label "$label" --arg path "$path" --arg type "$folder_type" --argjson devices "$devices" '{label: $label, path: $path, type: $type, devices: $devices}')"
  if [[ "$existing" == "null" ]]; then
    source_id="$(jq -r '.migrationFrom // empty' <<<"$folder")"
    # Transfer versioning/pause preferences, never grant a legacy manual peer
    # access to a new work or personal root.
    preferences="$(jq -c --arg id "$source_id" 'map(select(.id == $id))[0] // {} | with_entries(select(.key == "versioning" or .key == "paused" or .key == "fsWatcherEnabled" or .key == "rescanIntervalS"))' <<<"$existing_folders")"
    payload="$(jq -c --arg id "$folder_id" --argjson fields "$payload" --argjson preferences "$preferences" '. + $preferences + $fields + {id: $id}' <<<"$folder_default")"
    api -X POST -H 'Content-Type: application/json' --data-binary "$payload" "$api_url/rest/config/folders" >/dev/null
  elif ! jq -e --argjson fields "$payload" '. as $existing | $fields | to_entries | all(.[]; $existing[.key] == .value)' <<<"$existing" >/dev/null; then
    encoded_id="$(jq -rn --arg id "$folder_id" '$id | @uri')"
    api -X PATCH -H 'Content-Type: application/json' --data-binary "$payload" "$api_url/rest/config/folders/$encoded_id" >/dev/null
  fi
done < <(jq -c '.[]' <<<"$folders_json")

desired_folder_ids="$(jq -c '[.[].id]' <<<"$folders_json")"
while IFS= read -r stale_id; do
  [[ -n "$stale_id" ]] || continue
  # Keep a private local configuration snapshot for a reviewed rollback.
  retired="$(api "$api_url/rest/config/folders/$stale_id")"
  backup="$(mktemp "$config_dir/fleet-retired-${stale_id}.XXXXXX.json")"
  chmod 600 "$backup"
  printf '%s\n' "$retired" >"$backup"
  api -X DELETE "$api_url/rest/config/folders/$stale_id" >/dev/null
done < <(api "$api_url/rest/config/folders" | jq -r --arg prefix "$managed_folder_prefix" --argjson desired "$desired_folder_ids" '[ .[] | select(.id | startswith($prefix)) | .id ] - $desired | .[] | @uri')

while IFS= read -r stale_id; do [[ -n "$stale_id" ]] && api -X DELETE "$api_url/rest/config/devices/$stale_id" >/dev/null; done < <(jq -r '.[] | @uri' <<<"$retired_device_ids")

if api "$api_url/rest/config/restart-required" | jq -e '.requiresRestart' >/dev/null; then api -X POST "$api_url/rest/system/restart" >/dev/null; fi
printf 'Syncthing fleet reconciled: %s peer(s), %s managed folder(s).\n' "$(jq 'length' <<<"$resolved_devices")" "$(jq 'length' <<<"$folders_json")"
jq -r '.[] | "Discovery deferred until the next timer: \(.)"' <<<"$deferred_peers"
