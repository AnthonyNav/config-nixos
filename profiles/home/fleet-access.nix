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
  tailscale =
    if pkgs.stdenv.hostPlatform.isDarwin then
      import ../../packages/native-tailscale.nix { inherit pkgs; }
    else
      pkgs.tailscale;
  sshProxyCommand = "${lib.getExe tailscale} nc %h %p";

  sshSettings = lib.mapAttrs (_: host: {
    User = host.username or username;
    ProxyCommand = sshProxyCommand;
    ServerAliveInterval = 15;
    ServerAliveCountMax = 3;
  }) sshHosts;

  fleetSsh = pkgs.writeShellApplication {
    name = "fleet-ssh";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      tailscale
    ];
    text = ''
            hosts_json=${lib.escapeShellArg (builtins.toJSON sshHostNames)}
            ssh_users_json=${
              lib.escapeShellArg (builtins.toJSON (lib.mapAttrs (_: host: host.username or username) sshHosts))
            }

            usage() {
              cat <<'EOF'
      Usage:
        fleet-ssh HOST
        fleet-ssh --list
        fleet-ssh --check

      Connects with Tailscale SSH to a declared SSH-capable fleet host.
      EOF
            }

            list_hosts() { jq -r '.[]' <<<"$hosts_json"; }

            check_fleet() {
              local status backend host row online ip
              status="$(tailscale status --json)"
              backend="$(jq -r '.BackendState // "Unknown"' <<<"$status")"
              printf 'Tailscale backend: %s\n' "$backend"
              [[ "$backend" == "Running" ]] || return 1

              while IFS= read -r host; do
                row="$(jq -c --arg host "$host" '
                  if ((.Self.HostName // "") == $host or (((.Self.DNSName // "") | split(".")[0]) == $host)) then
                    {online: true, ip: ([.Self.TailscaleIPs[]? | select(contains(":") | not)][0] // "-")}
                  else
                    ([.Peer[]? | select((.HostName // "") == $host or (((.DNSName // "") | split(".")[0]) == $host)) | {online: (.Online // false), ip: ([.TailscaleIPs[]? | select(contains(":") | not)][0] // "-")}][0] // {online: false, ip: "-"})
                  end
                ' <<<"$status")"
                online="$(jq -r '.online' <<<"$row")"
                ip="$(jq -r '.ip' <<<"$row")"
                printf '%-12s online=%-5s ip=%s\n' "$host" "$online" "$ip"
              done < <(list_hosts)
            }

            case "''${1:-}" in
              --list) list_hosts ;;
              --check) check_fleet ;;
              -h|--help|"") usage ;;
              *)
                target="$1"
                if ! jq -e --arg host "$target" 'index($host) != null' <<<"$hosts_json" >/dev/null; then
                  printf "fleet-ssh: '%s' is not a declared SSH-capable fleet host.\n" "$target" >&2
                  exit 64
                fi
                target_user="$(jq -er --arg host "$target" '.[$host]' <<<"$ssh_users_json")"
                exec tailscale ssh "$target_user@$target"
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

  programs.ssh.settings = sshSettings;
  home.packages = [ fleetSsh ];
}
