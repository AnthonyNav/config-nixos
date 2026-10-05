# Executed by the user service, never through an interactive shell profile.
orca_binary=$1
orca_port=$2
unset DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE ELECTRON_RUN_AS_NODE ORCA_USER_DATA_PATH
export LIBGL_ALWAYS_SOFTWARE=1

printf '%s\n' 'Orca: waiting for Tailscale connectivity.'
while true; do
  if tailscale status --json 2>/dev/null | jq -e '.BackendState == "Running" and .Self.Online == true' >/dev/null; then
    pairing_ip=$(tailscale ip -4 2>/dev/null || true)
    if printf '%s' "$pairing_ip" | jq -R -e '
      split(".") as $ip | ($ip | length) == 4 and
      all($ip[]; test("^[0-9]{1,3}$") and (tonumber >= 0 and tonumber <= 255)) and
      $ip[0] == "100" and ($ip[1] | tonumber) >= 64 and ($ip[1] | tonumber) <= 127
    ' >/dev/null 2>&1; then
      break
    fi
  fi
  sleep 3
done

# Upstream may choose another port after a collision. Never silently advertise
# a listener outside the fleet firewall contract; diagnostics also check readiness.
if [[ -n "$(ss -H -ltn "sport = :$orca_port")" ]]; then
  printf '%s\n' 'Orca: configured TCP port is already occupied.' >&2
  exit 78
fi
exec "$orca_binary" serve --port "$orca_port" --pairing-address "$pairing_ip" --json
