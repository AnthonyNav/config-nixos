#!/usr/bin/env bash
set -euo pipefail

script_under_test="${1:?usage: check-input-share.sh SCRIPT}"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

mkdir -p "$test_root/bin" "$test_root/run" "$test_root/state"
clients_file="$test_root/clients"
commands_file="$test_root/commands"
: >"$clients_file"
: >"$commands_file"

printf '#!%s\n' "$(command -v bash)" >"$test_root/bin/lan-mouse"
cat >>"$test_root/bin/lan-mouse" <<'EOF'
set -euo pipefail

shift # cli
case "$1" in
  list)
    cat "$INPUT_SHARE_TEST_CLIENTS"
    ;;
  remove-client)
    : >"$INPUT_SHARE_TEST_CLIENTS"
    ;;
  add-client)
    shift
    host=""
    ip=""
    while (($# > 0)); do
      case "$1" in
        --hostname)
          host="$2"
          shift 2
          ;;
        --ips)
          ip="$2"
          shift 2
          ;;
      esac
    done
    id="$(($(wc -l <"$INPUT_SHARE_TEST_CLIENTS") + 1))"
    printf 'id %s: %s: %s\n' "$id" "$host" "$ip" >>"$INPUT_SHARE_TEST_CLIENTS"
    ;;
  set-position)
    printf 'set-position %s %s\n' "$2" "$3" >>"$INPUT_SHARE_TEST_COMMANDS"
    ;;
  activate | save-config)
    ;;
  *)
    exit 64
    ;;
esac
EOF

printf '#!%s\n' "$(command -v bash)" >"$test_root/bin/tailscale"
cat >>"$test_root/bin/tailscale" <<'EOF'
set -euo pipefail

[[ "${1:-}" == "status" && "${2:-}" == "--json" ]]
cat <<'JSON'
{
  "Peer": {
    "desktop": {
      "HostName": "desktop",
      "DNSName": "desktop.example.ts.net.",
      "TailscaleIPs": ["100.64.0.1", "fd7a:115c:a1e0::1"]
    },
    "victus": {
      "HostName": "victus",
      "DNSName": "victus.example.ts.net.",
      "TailscaleIPs": ["100.64.0.2", "fd7a:115c:a1e0::2"]
    }
  }
}
JSON
EOF

chmod +x "$test_root/bin/lan-mouse" "$test_root/bin/tailscale"

export INPUT_SHARE_HOST="thinkpad"
export INPUT_SHARE_PEERS_JSON='[
  {"host":"desktop","position":"left"},
  {"host":"victus","position":"bottom"}
]'
export INPUT_SHARE_TEST_CLIENTS="$clients_file"
export INPUT_SHARE_TEST_COMMANDS="$commands_file"
export PATH="$test_root/bin:$PATH"
export XDG_RUNTIME_DIR="$test_root/run"
export XDG_STATE_HOME="$test_root/state"

bash "$script_under_test" all >/dev/null
grep -q 'desktop' "$clients_file"
grep -q 'victus' "$clients_file"
grep -q '^set-position 1 left$' "$commands_file"
grep -q '^set-position 2 bottom$' "$commands_file"

bash "$script_under_test" pair desktop >/dev/null
grep -q 'desktop' "$clients_file"
if grep -q 'victus' "$clients_file"; then
  echo "pair profile retained an unrelated peer" >&2
  exit 1
fi

bash "$script_under_test" reconcile >/dev/null
[[ "$(wc -l <"$clients_file")" -eq 1 ]]
grep -q 'desktop' "$clients_file"

bash "$script_under_test" off >/dev/null
[[ ! -s "$clients_file" ]]
jq -e '.mode == "off"' "$XDG_STATE_HOME/input-sharing/profile.json" >/dev/null

if bash "$script_under_test" pair unknown >/dev/null 2>&1; then
  echo "unknown peer was accepted" >&2
  exit 1
else
  status=$?
  [[ "$status" -eq 64 ]]
fi

printf '%s\n' '{"mode":"invalid"}' >"$XDG_STATE_HOME/input-sharing/profile.json"
bash "$script_under_test" reconcile >/dev/null
[[ "$(wc -l <"$clients_file")" -eq 2 ]]

printf '%s\n' '{"mode":"pair","host":"unknown"}' >"$XDG_STATE_HOME/input-sharing/profile.json"
bash "$script_under_test" reconcile >/dev/null
[[ "$(wc -l <"$clients_file")" -eq 2 ]]

echo "input-share profile tests passed"
