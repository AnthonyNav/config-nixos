#!/usr/bin/env bash
set -euo pipefail

peers_json="${INPUT_SHARE_PEERS_JSON:-[]}"

wait_for_lan_mouse() {
  for _ in $(seq 1 40); do
    if lan-mouse cli list >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.25
  done
  return 1
}

if ! wait_for_lan_mouse; then
  echo "Lan Mouse daemon is not ready; retry with: input-share-reconcile" >&2
  exit 75
fi

resolved_rows=()
peer_count="$(jq 'length' <<<"$peers_json")"

if (( peer_count > 0 )); then
  tailscale_json=""
  for _ in $(seq 1 40); do
    if tailscale_json="$(tailscale status --json 2>/dev/null)"; then
      break
    fi
    sleep 0.25
  done

  if [[ -z "$tailscale_json" ]]; then
    echo "Tailscale is not ready; leaving the existing Lan Mouse topology unchanged." >&2
    exit 75
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
      exit 75
    fi

    resolved_rows+=("$host"$'\t'"$position"$'\t'"$ip")
  done < <(jq -r '.[] | [.host, .position] | @tsv' <<<"$peers_json")
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
    exit 1
  fi

  lan-mouse cli set-position "$client_id" "$position"
  lan-mouse cli activate "$client_id"
done

lan-mouse cli save-config
printf 'Lan Mouse topology reconciled (%s outgoing peer(s)).\n' "$peer_count"
