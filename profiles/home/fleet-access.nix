{
  fleetInventory,
  lib,
  pkgs,
  username,
  ...
}:

let
  sshHosts = lib.filterAttrs (_: host: (host.connectivity.ssh or false)) fleetInventory;
  sshHostNames = builtins.attrNames sshHosts;

  sshSettings = lib.mapAttrs (_: _: {
    User = username;
    ServerAliveInterval = 15;
    ServerAliveCountMax = 3;
  }) sshHosts;

  fleetSsh = pkgs.writeShellApplication {
    name = "fleet-ssh";
    runtimeInputs = with pkgs; [
      coreutils
      jq
      tailscale
    ];
    text = ''
      hosts_json=${lib.escapeShellArg (builtins.toJSON sshHostNames)}
      ssh_user=${lib.escapeShellArg username}

      usage() {
        cat <<'EOF'
Usage:
  fleet-ssh HOST
  fleet-ssh --list
  fleet-ssh --check

Connects with Tailscale SSH to a declared SSH-capable fleet host.
EOF
      }

      list_hosts() {
        jq -r '.[]' <<<"$hosts_json"
      }

      check_fleet() {
        local status backend host row online ip
        status="$(tailscale status --json)"
        backend="$(jq -r '.BackendState // "Unknown"' <<<"$status")"
        printf 'Tailscale backend: %s\n' "$backend"

        if [[ "$backend" != "Running" ]]; then
          return 1
        fi

        while IFS= read -r host; do
          row="$(
            jq -c --arg host "$host" '
              if ((.Self.HostName // "") == $host or (((.Self.DNSName // "") | split(".")[0]) == $host)) then
                {
                  online: true,
                  ip: ([.Self.TailscaleIPs[]? | select(contains(":") | not)][0] // "-")
                }
              else
                ([
                  .Peer[]?
                  | select(
                      (.HostName // "") == $host
                      or (((.DNSName // "") | split(".")[0]) == $host)
                    )
                  | {
                      online: (.Online // false),
                      ip: ([.TailscaleIPs[]? | select(contains(":") | not)][0] // "-")
                    }
                ][0] // {online: false, ip: "-"})
              end
            ' <<<"$status"
          )"
          online="$(jq -r '.online' <<<"$row")"
          ip="$(jq -r '.ip' <<<"$row")"
          printf '%-12s online=%-5s ip=%s\n' "$host" "$online" "$ip"
        done < <(list_hosts)
      }

      case "''${1:-}" in
        --list)
          list_hosts
          ;;
        --check)
          check_fleet
          ;;
        -h|--help|"")
          usage
          ;;
        *)
          target="$1"
          if ! jq -e --arg host "$target" 'index($host) != null' <<<"$hosts_json" >/dev/null; then
            printf "fleet-ssh: '%s' is not a declared SSH-capable fleet host.\n" "$target" >&2
            printf 'Available hosts:\n' >&2
            list_hosts >&2
            exit 64
          fi
          exec tailscale ssh "$ssh_user@$target"
          ;;
      esac
    '';
  };
in
{
  assertions = [
    {
      assertion = sshHostNames != [ ];
      message = "The fleet must contain at least one SSH-capable host.";
    }
  ];

  # Normal `ssh thinkpad` remains available for tools such as nixos-rebuild,
  # while `fleet-ssh thinkpad` is preferred interactively because `tailscale
  # ssh` validates the destination host key through the coordination server.
  programs.ssh.settings = sshSettings;

  home.packages = [ fleetSsh ];
}
