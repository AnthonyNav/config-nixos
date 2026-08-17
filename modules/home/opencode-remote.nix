{
  hostFeatures,
  lib,
  pkgs,
  ...
}:

let
  policy = import ../../inventory/opencode-remote.nix;
  remote = hostFeatures.opencodeRemote or { };
  enabled = remote.enable or false;
  opencodePackages = import ./opencode-packages.nix { inherit lib pkgs; };

  envFileRelative = policy.auth.envFile;
  envFileSystemd = "%h/${envFileRelative}";
  localUrl = "http://${policy.backend.hostname}:${toString policy.backend.port}";

  opencodeRemoteBootstrap = pkgs.writeShellApplication {
    name = "opencode-remote-bootstrap";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.python3
      pkgs.systemd
    ];
    text = ''
      mode="''${1:---if-missing}"
      config_dir="$HOME/${builtins.dirOf envFileRelative}"
      env_file="$HOME/${envFileRelative}"

      generate_secret() {
        local password temporary
        install -d -m 700 "$config_dir"
        password="$(python3 - <<'PY'
import secrets
print(secrets.token_urlsafe(32))
PY
        )"
        temporary="$(mktemp "$config_dir/.server.env.XXXXXX")"
        chmod 600 "$temporary"
        printf 'OPENCODE_SERVER_PASSWORD=%s\n' "$password" > "$temporary"
        mv -f "$temporary" "$env_file"
        chmod 600 "$env_file"
      }

      case "$mode" in
        --if-missing)
          if [[ -e "$env_file" ]]; then
            chmod 600 "$env_file"
            exit 0
          fi
          generate_secret
          ;;
        --rotate)
          generate_secret
          systemctl --user try-restart opencode-remote.service || true
          printf 'OpenCode Remote password rotated. Run `opencode-remote credentials` to view the new value.\n'
          ;;
        *)
          printf 'Usage: opencode-remote-bootstrap [--if-missing|--rotate]\n' >&2
          exit 64
          ;;
      esac
    '';
  };

  opencodeRemote = pkgs.writeShellApplication {
    name = "opencode-remote";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
      pkgs.systemd
      pkgs.tailscale
      opencodePackages.default
      opencodeRemoteBootstrap
    ];
    text = ''
      env_file="$HOME/${envFileRelative}"
      auth_user=${lib.escapeShellArg policy.auth.username}
      local_url=${lib.escapeShellArg localUrl}

      read_password() {
        local key value password=""
        if [[ ! -r "$env_file" ]]; then
          printf 'OpenCode Remote credentials are missing: %s\n' "$env_file" >&2
          return 1
        fi
        while IFS='=' read -r key value; do
          if [[ "$key" == "OPENCODE_SERVER_PASSWORD" ]]; then
            password="$value"
            break
          fi
        done < "$env_file"
        if [[ -z "$password" ]]; then
          printf 'OPENCODE_SERVER_PASSWORD is missing from %s\n' "$env_file" >&2
          return 1
        fi
        printf '%s' "$password"
      }

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
        local password
        printf 'OpenCode service: '
        systemctl --user is-active opencode-remote.service || true
        printf 'Tailscale backend: '
        tailscale status --json | jq -r '.BackendState // "Unknown"'
        printf 'Remote URL: '
        remote_url || true
        password="$(read_password)" || return 1
        printf 'OpenCode health: '
        curl --fail --silent --show-error \
          --user "$auth_user:$password" \
          "$local_url/global/health" | jq -c .
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
        credentials)
          password="$(read_password)"
          printf 'URL: '
          remote_url
          printf 'Username: %s\n' "$auth_user"
          printf 'Password: %s\n' "$password"
          ;;
        attach)
          password="$(read_password)"
          exec opencode attach "$local_url" --username "$auth_user" --password "$password"
          ;;
        rotate-password)
          exec opencode-remote-bootstrap --rotate
          ;;
        logs)
          exec journalctl --user -u opencode-remote.service -f
          ;;
        -h|--help|help)
          cat <<'EOF'
Usage: opencode-remote [status|url|credentials|attach|rotate-password|logs]
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
      message = "Remote OpenCode must listen only on 127.0.0.1; Tailscale Serve owns network exposure.";
    }
    {
      assertion = !(lib.hasPrefix "/" policy.auth.envFile);
      message = "Remote OpenCode credential path must remain relative to the user's home directory.";
    }
  ];

  home.packages = lib.optionals enabled [
    opencodeRemote
    opencodeRemoteBootstrap
  ];

  home.activation.bootstrapOpenCodeRemote = lib.mkIf enabled (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${lib.getExe opencodeRemoteBootstrap} --if-missing
    ''
  );

  systemd.user.services.opencode-remote = lib.mkIf enabled {
    Unit = {
      Description = "Persistent OpenCode Web backend for private Tailscale access";
      Documentation = "https://opencode.ai/docs/web/";
      ConditionPathExists = envFileSystemd;
    };

    Service = {
      Type = "simple";
      WorkingDirectory = "%h";
      UMask = "0077";
      EnvironmentFile = envFileSystemd;
      Environment = [
        "OPENCODE_SERVER_USERNAME=${policy.auth.username}"
        "DISPLAY="
        "WAYLAND_DISPLAY="
      ];
      ExecStart = "${lib.getExe opencodePackages.default} web --hostname ${policy.backend.hostname} --port ${toString policy.backend.port}";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install.WantedBy = [ "default.target" ];
  };
}
