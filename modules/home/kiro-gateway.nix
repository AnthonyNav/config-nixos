# kiro-gateway: arranque automático (systemd --user) para el proxy que expone
# los modelos de Kiro como API OpenAI/Anthropic-compatible, consumido por
# opencode. Repo: https://github.com/AnthonyNav/kiro-gateway
#
# DISEÑO A PROPÓSITO DESACOPLADO DE NIX (kiro-gateway es una herramienta de
# comunidad que puede ser temporal — ver docs/maintainer.md):
#   - El código proviene de una revisión bloqueada del fork; el venv y los
#     SECRETOS (.env con PROXY_API_KEY) viven fuera del store.
#   - ~/.config/opencode/opencode.json define el provider y los modelos base
#     desde Nix. El catalogo detectado se guarda en XDG state, fuera del store.
#   - Este módulo aporta unidades systemd --user. Una unidad .path inicia el
#     servicio cuando el venv aparece, sin depender de una sola comprobación al
#     inicio de sesión.
#
# Para desinstalar por completo: quita el import de este archivo en home.nix
# y borra ~/.local/share/kiro-gateway (y opcionalmente ~/.config/opencode).
#
# Bootstrap manual (una sola vez):
#   crea ~/.config/kiro-gateway/.env y ejecuta kiro-gateway-bootstrap.
{ inputs, pkgs, ... }:

let
  gatewaySource = inputs.kiro-gateway;
  gatewayRequirements = ./kiro-gateway-requirements.txt;
  kiroGatewayBootstrap = pkgs.writeShellApplication {
    name = "kiro-gateway-bootstrap";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.python3
      pkgs.systemd
    ];
    text = ''
      if [[ "''${1:-}" != "" && "''${1:-}" != "--if-configured" ]]; then
        printf 'Usage: kiro-gateway-bootstrap [--if-configured]\n' >&2
        exit 64
      fi

      config_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/kiro-gateway"
      env_file="$config_dir/.env"
      legacy_env="$HOME/dev/shared/kiro-gateway/.env"
      data_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/kiro-gateway"
      venv="$data_dir/venv"
      marker="$data_dir/requirements.sha256"

      if [[ ! -r "$env_file" ]]; then
        if [[ -r "$legacy_env" ]]; then
          mkdir -p "$config_dir"
          install -m 600 "$legacy_env" "$env_file"
          printf 'Migrated Kiro Gateway environment to %s\n' "$env_file"
        elif [[ "''${1:-}" == "--if-configured" ]]; then
          exit 0
        else
          printf 'Create %s with PROXY_API_KEY and KIRO_CREDS_FILE first.\n' "$env_file" >&2
          exit 1
        fi
      fi

      mkdir -p "$data_dir"
      if [[ ! -x "$venv/bin/python" ]]; then
        python3 -m venv "$venv"
      fi

      requirements_digest="$(sha256sum ${gatewaySource}/requirements.txt ${gatewayRequirements} | sha256sum | cut -d ' ' -f 1)"
      if [[ ! -f "$marker" || "$(<"$marker")" != "$requirements_digest" ]]; then
        "$venv/bin/python" -m pip install \
          --requirement ${gatewaySource}/requirements.txt \
          --constraint ${gatewayRequirements}
        printf '%s\n' "$requirements_digest" > "$marker"
      fi

      systemctl --user start kiro-gateway.path
      systemctl --user restart kiro-gateway.service
      systemctl --user start kiro-opencode-model-sync.service
    '';
  };
in
{
  home.packages = [ kiroGatewayBootstrap ];

  systemd.user.services.kiro-gateway = {
    Unit = {
      Description = "kiro-gateway: proxy OpenAI/Anthropic-compatible para los modelos de Kiro (usado por opencode)";
      Documentation = "https://github.com/AnthonyNav/kiro-gateway";
    };

    Service = {
      WorkingDirectory = "${gatewaySource}";
      # Secretos (PROXY_API_KEY, ruta a las credenciales de Kiro) fuera del
      # store, cargados en runtime desde este archivo.
      EnvironmentFile = "%h/.config/kiro-gateway/.env";
      # Nota: NO se fija LD_LIBRARY_PATH aquí — nix-ld (modules/system/ai-helper.nix)
      # ya expone NIX_LD/NIX_LD_LIBRARY_PATH globalmente vía PAM, y systemd --user
      # hereda esas variables (confirmado con `systemctl --user show-environment`),
      # así que los wheels compilados del venv (tiktoken, pydantic-core, uvloop)
      # resuelven sus libs sin configuración extra.
      ExecStart = "%h/.local/share/kiro-gateway/venv/bin/python ${gatewaySource}/main.py";
      Restart = "on-failure";
      RestartSec = 5;
    };

    # La unidad .path activa este servicio cuando termina el bootstrap local.
  };

  systemd.user.paths.kiro-gateway = {
    Unit.Description = "Espera el venv de kiro-gateway";
    Path.PathExists = "%h/.local/share/kiro-gateway/venv/bin/python";
    Install.WantedBy = [ "default.target" ];
  };

  # OpenCode needs an explicit models map for custom OpenAI-compatible
  # providers. The gateway writes only the discovered catalog to XDG state;
  # the provider configuration remains managed by Home Manager.
  systemd.user.services.kiro-opencode-model-sync = {
    Unit = {
      Description = "Sincroniza los modelos de Kiro Gateway hacia OpenCode";
      After = [ "kiro-gateway.service" ];
      Wants = [ "kiro-gateway.service" ];
      ConditionPathExists = "%h/.local/share/kiro-gateway/venv/bin/python";
    };

    Service = {
      Type = "oneshot";
      EnvironmentFile = "%h/.config/kiro-gateway/.env";
      ExecStart = "%h/.local/share/kiro-gateway/venv/bin/python ${gatewaySource}/scripts/sync-opencode-models.py --base-config %h/.config/opencode/opencode.json --config %h/.local/state/opencode/kiro-models.json --wait-seconds 15";
    };
  };

  systemd.user.timers.kiro-opencode-model-sync = {
    Unit.Description = "Actualiza periodicamente el catalogo de modelos de Kiro en OpenCode";
    Timer = {
      OnBootSec = "2min";
      OnUnitActiveSec = "1h";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # Atajos de conveniencia, autocontenidos en este módulo (no tocan zsh.nix,
  # así que desaparecen solos si se quita el import).
  home.shellAliases = {
    kgw-up = "systemctl --user start kiro-gateway";
    kgw-down = "systemctl --user stop kiro-gateway";
    kgw-restart = "systemctl --user restart kiro-gateway";
    kgw-status = "systemctl --user status kiro-gateway";
    kgw-logs = "journalctl --user -u kiro-gateway -f";
    kgw-models-sync = "systemctl --user start kiro-opencode-model-sync";
  };
}
