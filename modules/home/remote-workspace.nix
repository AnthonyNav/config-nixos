{
  hostFeatures,
  lib,
  pkgs,
  ...
}:

let
  policy = import ../../inventory/remote-workspace.nix;
  remote = hostFeatures.remoteWorkspace or { };
  enabled = remote.enable or false;

  remoteWorkspace = pkgs.writeShellApplication {
    name = "remote-workspace";
    runtimeInputs = [
      pkgs.jq
      pkgs.systemd
      pkgs.tailscale
      pkgs.zellij
    ];
    text = ''
      config_file="$HOME/${policy.configFile}"
      backend_ip=${lib.escapeShellArg policy.backend.hostname}
      backend_port=${toString policy.backend.port}

      remote_url() {
        local dns_name
        dns_name="$(tailscale status --json | jq -r '.Self.DNSName // empty')"
        dns_name="''${dns_name%.}"
        if [[ -z "$dns_name" ]]; then
          printf 'Unable to determine this host Tailscale DNS name.\n' >&2
          return 1
        fi
        printf 'https://%s\n' "$dns_name"
      }

      status() {
        printf 'Workspace service: '
        systemctl --user is-active remote-workspace.service || true
        printf 'Zellij web: '
        zellij --config "$config_file" web --status --timeout 5 --ip "$backend_ip" --port "$backend_port" || true
        printf 'Remote URL: '
        remote_url || true
        printf 'Tailscale Serve:\n'
        tailscale serve status || true
      }

      case "''${1:-status}" in
        status)
          status
          ;;
        url)
          remote_url
          ;;
        create-token)
          exec zellij --config "$config_file" web --create-token
          ;;
        create-read-only-token)
          exec zellij --config "$config_file" web --create-read-only-token
          ;;
        list-tokens)
          exec zellij --config "$config_file" web --list-tokens
          ;;
        sessions)
          exec zellij --config "$config_file" list-sessions
          ;;
        -h|--help|help)
          cat <<'EOF'
Usage: remote-workspace [status|url|create-token|create-read-only-token|list-tokens|sessions]

The workspace is provider-agnostic: start Claude Code, Codex, OpenCode, Kiro CLI,
or any other terminal program inside a Zellij session.
EOF
          ;;
        *)
          printf 'Unknown command: %s\n' "$1" >&2
          exit 64
          ;;
      esac
    '';
  };
in
{
  assertions = lib.optionals enabled [
    {
      assertion = policy.backend.hostname == "127.0.0.1";
      message = "The generic remote workspace must listen only on 127.0.0.1.";
    }
    {
      assertion = !(lib.hasPrefix "/" policy.configFile);
      message = "The remote workspace config path must remain relative to the user's home directory.";
    }
  ];

  home.packages = lib.optionals enabled [
    pkgs.zellij
    remoteWorkspace
  ];

  home.file = lib.mkIf enabled {
    ${policy.configFile}.text = ''
      web_server true
      web_server_ip "${policy.backend.hostname}"
      web_server_port ${toString policy.backend.port}
      enforce_https_on_localhost false
    '';
  };

  systemd.user.services.remote-workspace = lib.mkIf enabled {
    Unit = {
      Description = "Persistent provider-agnostic remote terminal workspace";
      Documentation = "https://zellij.dev/documentation/web-client.html";
    };

    Service = {
      Type = "simple";
      UMask = "0077";
      ExecStart = "${lib.getExe pkgs.zellij} --config %h/${policy.configFile} web";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install.WantedBy = [ "default.target" ];
  };
}
