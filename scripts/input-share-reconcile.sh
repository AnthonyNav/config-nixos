#!/usr/bin/env bash
set -euo pipefail

peers_json="${INPUT_SHARE_PEERS_JSON:-[]}"
local_host="${INPUT_SHARE_HOST:-unknown}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/input-sharing"
state_file="$state_dir/profile.json"
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

mkdir -p "$runtime_dir"
exec 9>"$runtime_dir/input-share.lock"
flock 9

usage() {
  cat <<'EOF'
Usage: input-share [reconcile|status|all|off|pair HOST]

  reconcile  Apply the persisted profile (defaults to all declared peers).
  status     Show the persisted profile and Lan Mouse clients.
  all        Activate every declared peer on its configured screen edge.
  off        Disable every outgoing peer; incoming control remains available.
  pair HOST  Activate only the selected declared peer.
EOF
}

wait_for_lan_mouse() {
  for _ in $(seq 1 40); do
    if lan-mouse cli list >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.25
  done
  return 1
}

write_profile() {
  local mode="$1"
  local host="${2:-}"
  local tmp_file

  mkdir -p "$state_dir"
  tmp_file="$(mktemp "$state_dir/.profile.XXXXXX")"
  jq -n --arg mode "$mode" --arg host "$host" \
    '{mode: $mode} + if $host == "" then {} else {host: $host} end' >"$tmp_file"
  chmod 600 "$tmp_file"
  mv "$tmp_file" "$state_file"
}

current_profile() {
  local profile

  if [[ ! -f "$state_file" ]]; then
    printf '%s\n' '{"mode":"all"}'
    return
  fi

  if jq -e '
    (.mode == "all" and (keys | sort) == ["mode"])
    or (.mode == "off" and (keys | sort) == ["mode"])
    or (.mode == "pair" and (.host | type) == "string" and (keys | sort) == ["host", "mode"])
  ' "$state_file" >/dev/null; then
    profile="$(jq -c . "$state_file")"
    if [[ "$(jq -r '.mode' <<<"$profile")" == "pair" ]] \
      && ! jq -e --arg host "$(jq -r '.host' <<<"$profile")" \
        'any(.[]; .host == $host)' <<<"$peers_json" >/dev/null; then
      echo "Persisted input-sharing peer is no longer allowed; defaulting to all." >&2
      printf '%s\n' '{"mode":"all"}'
    else
      printf '%s\n' "$profile"
    fi
  else
    echo "Invalid input-sharing profile at $state_file; defaulting to all." >&2
    printf '%s\n' '{"mode":"all"}'
  fi
}

selected_peers() {
  local profile="$1"
  local mode
  local host

  mode="$(jq -r '.mode' <<<"$profile")"
  case "$mode" in
    all)
      printf '%s\n' "$peers_json"
      ;;
    off)
      printf '%s\n' '[]'
      ;;
    pair)
      host="$(jq -r '.host' <<<"$profile")"
      jq -c --arg host "$host" '[.[] | select(.host == $host)]' <<<"$peers_json"
      ;;
    *)
      echo "Unsupported input-sharing profile mode: $mode" >&2
      return 64
      ;;
  esac
}

reconcile() {
  local profile="$1"
  local active_peers_json
  local peer_count
  local tailscale_json=""
  local host
  local position
  local ip
  local row
  local id
  local client_id
  local -a resolved_rows=()
  local -a current_ids=()

  if ! wait_for_lan_mouse; then
    echo "Lan Mouse daemon is not ready; retry with: input-share reconcile" >&2
    return 75
  fi

  active_peers_json="$(selected_peers "$profile")"
  peer_count="$(jq 'length' <<<"$active_peers_json")"

  if ((peer_count > 0)); then
    for _ in $(seq 1 40); do
      if tailscale_json="$(tailscale status --json 2>/dev/null)"; then
        break
      fi
      sleep 0.25
    done

    if [[ -z "$tailscale_json" ]]; then
      echo "Tailscale is not ready; leaving the existing Lan Mouse topology unchanged." >&2
      return 75
    fi

    while IFS=$'\t' read -r host position; do
      ip="$(
        jq -r --arg host "$host" '
          [
            .Peer[]?
            | select(
                (.HostName // "") == $host
                or (((.DNSName // "") | split(".")[0]) == $host)
              )
            | .TailscaleIPs[]?
            | select(contains(":") | not)
          ][0] // empty
        ' <<<"$tailscale_json"
      )"

      if [[ -z "$ip" ]]; then
        echo "Tailscale peer '$host' is not available; leaving the existing Lan Mouse topology unchanged." >&2
        return 75
      fi

      resolved_rows+=("$host"$'\t'"$position"$'\t'"$ip")
    done < <(jq -r '.[] | [.host, .position] | @tsv' <<<"$active_peers_json")
  fi

  mapfile -t current_ids < <(lan-mouse cli list | sed -n 's/^id \([0-9][0-9]*\):.*/\1/p')
  for id in "${current_ids[@]}"; do
    lan-mouse cli remove-client "$id"
  done

  for row in "${resolved_rows[@]}"; do
    IFS=$'\t' read -r host position ip <<<"$row"
    lan-mouse cli add-client --hostname "$host" --ips "$ip"

    client_id="$(
      lan-mouse cli list \
        | sed -n "s/^id \\([0-9][0-9]*\\): ${host}:.*/\\1/p" \
        | head -n1
    )"

    if [[ -z "$client_id" ]]; then
      echo "Lan Mouse did not expose a client id for '$host'." >&2
      return 1
    fi

    lan-mouse cli set-position "$client_id" "$position"
    lan-mouse cli activate "$client_id"
  done

  lan-mouse cli save-config
  printf 'Lan Mouse topology reconciled on %s (%s outgoing peer(s)).\n' "$local_host" "$peer_count"
}

command="${1:-reconcile}"
case "$command" in
  reconcile)
    [[ $# -le 1 ]] || { usage >&2; exit 64; }
    reconcile "$(current_profile)"
    ;;
  status)
    [[ $# -eq 1 ]] || { usage >&2; exit 64; }
    profile="$(current_profile)"
    printf 'Host: %s\nProfile: %s\n' "$local_host" "$(jq -c . <<<"$profile")"
    if wait_for_lan_mouse; then
      lan-mouse cli list
    else
      echo "Lan Mouse daemon is not ready." >&2
      exit 75
    fi
    ;;
  all)
    [[ $# -eq 1 ]] || { usage >&2; exit 64; }
    write_profile all
    reconcile '{"mode":"all"}'
    ;;
  off)
    [[ $# -eq 1 ]] || { usage >&2; exit 64; }
    write_profile off
    reconcile '{"mode":"off"}'
    ;;
  pair)
    [[ $# -eq 2 ]] || { usage >&2; exit 64; }
    target="$2"
    if ! jq -e --arg host "$target" 'any(.[]; .host == $host)' <<<"$peers_json" >/dev/null; then
      echo "Host '$target' is not an allowed peer for '$local_host'." >&2
      exit 64
    fi
    write_profile pair "$target"
    reconcile "$(jq -nc --arg host "$target" '{mode: "pair", host: $host}')"
    ;;
  -h | --help | help)
    usage
    ;;
  *)
    echo "Unknown input-share command: $command" >&2
    usage >&2
    exit 64
    ;;
esac
