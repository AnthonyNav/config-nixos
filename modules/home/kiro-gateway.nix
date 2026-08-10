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
# Bootstrap manual (una sola vez): kiro-gateway-bootstrap detecta las
# credenciales locales y crea ~/.config/kiro-gateway/.env sin llevar secretos
# al store.
{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  gatewaySource = inputs.kiro-gateway;
  gatewayRequirements = ./kiro-gateway-requirements.txt;
  kiroOpenCodeModelSync = pkgs.writeShellApplication {
    name = "kiro-opencode-model-sync";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.python3
    ];
    text = ''
            env_file="''${XDG_CONFIG_HOME:-$HOME/.config}/kiro-gateway/.env"
            catalog="$HOME/.local/state/opencode/kiro-models.json"

            if [[ ! -r "$env_file" || ! -r "$catalog" ]]; then
              printf 'Kiro model synchronization requires its local environment and OpenCode catalog.\n' >&2
              exit 1
            fi

            proxy_api_key="$(python3 - "$env_file" <<'PY'
      import re
      import sys

      for line in open(sys.argv[1], encoding="utf-8"):
          match = re.fullmatch(r"\s*PROXY_API_KEY\s*=\s*(.*?)\s*", line)
          if not match:
              continue
          value = match.group(1)
          if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
              value = value[1:-1]
          print(value, end="")
          break
      PY
            )"
            if [[ -z "$proxy_api_key" ]]; then
              printf 'Kiro model synchronization requires a non-empty PROXY_API_KEY.\n' >&2
              exit 1
            fi

            temporary_config="$(mktemp "''${XDG_RUNTIME_DIR:-/tmp}/kiro-opencode-models.XXXXXX")"
            trap 'rm -f "$temporary_config"' EXIT

            PROXY_API_KEY="$proxy_api_key" python3 - "$catalog" "$temporary_config" <<'PY'
      import json
      import os
      import sys

      catalog_path, temporary_path = sys.argv[1:]
      with open(catalog_path, encoding="utf-8") as file:
          config = json.load(file)

      config["provider"]["kiro"]["options"]["apiKey"] = os.environ["PROXY_API_KEY"]
      with open(temporary_path, "w", encoding="utf-8") as file:
          json.dump(config, file, indent=2)
          file.write("\n")
      os.chmod(temporary_path, 0o600)
      PY

            python3 ${gatewaySource}/scripts/sync-opencode-models.py \
              --config "$temporary_config" \
              --wait-seconds 15

            python3 - "$catalog" "$temporary_config" <<'PY'
      import json
      import os
      import sys
      import tempfile

      catalog_path, temporary_path = sys.argv[1:]
      with open(temporary_path, encoding="utf-8") as file:
          config = json.load(file)
      config["provider"]["kiro"]["options"]["apiKey"] = "{env:PROXY_API_KEY}"

      descriptor, replacement_path = tempfile.mkstemp(prefix=".kiro-models.", dir=os.path.dirname(catalog_path))
      try:
          with os.fdopen(descriptor, "w", encoding="utf-8") as file:
              json.dump(config, file, indent=2)
              file.write("\n")
          os.chmod(replacement_path, 0o600)
          os.replace(replacement_path, catalog_path)
      except Exception:
          os.unlink(replacement_path)
          raise
      PY
    '';
  };
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
            configured_marker="$data_dir/configured"

            has_configured_credentials() {
              python3 - "$env_file" <<'PY'
      import re
      import sys

      try:
          lines = open(sys.argv[1], encoding="utf-8")
      except OSError:
          raise SystemExit(1)

      keys = {"REFRESH_TOKEN", "KIRO_CREDS_FILE", "KIRO_CLI_DB_FILE"}
      for line in lines:
          match = re.fullmatch(r"\s*([A-Z_][A-Z0-9_]*)\s*=\s*(.*?)\s*", line)
          if not match or match.group(1) not in keys:
              continue
          value = match.group(2)
          if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
              value = value[1:-1]
          if value:
              raise SystemExit(0)
      raise SystemExit(1)
      PY
            }

            detect_credentials() {
              python3 - "$HOME" <<'PY'
      import json
      import sqlite3
      import sys
      from pathlib import Path

      home = Path(sys.argv[1])

      def usable_json(path):
          try:
              with path.open(encoding="utf-8") as file:
                  credentials = json.load(file)
          except (OSError, json.JSONDecodeError):
              return False
          if not isinstance(credentials, dict) or not isinstance(credentials.get("refreshToken"), str):
              return False
          if not credentials["refreshToken"]:
              return False
          client_id = credentials.get("clientId")
          client_secret = credentials.get("clientSecret")
          if client_id or client_secret:
              return isinstance(client_id, str) and bool(client_id) and isinstance(client_secret, str) and bool(client_secret)
          client_id_hash = credentials.get("clientIdHash")
          if not isinstance(client_id_hash, str) or not client_id_hash:
              return True
          registration = path.parent / f"{client_id_hash}.json"
          try:
              with registration.open(encoding="utf-8") as file:
                  registration_data = json.load(file)
          except (OSError, json.JSONDecodeError):
              return False
          return bool(registration_data.get("clientId")) and bool(registration_data.get("clientSecret"))

      def usable_sqlite(path):
          try:
              connection = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
              with connection:
                  rows = connection.execute(
                      "SELECT key, value FROM auth_kv WHERE key IN (?, ?, ?, ?, ?)",
                      (
                          "kirocli:social:token",
                          "kirocli:odic:token",
                          "codewhisperer:odic:token",
                          "kirocli:odic:device-registration",
                          "codewhisperer:odic:device-registration",
                      ),
                  ).fetchall()
          except sqlite3.Error:
              return False
          values = {}
          try:
              for key, value in rows:
                  values[key] = json.loads(value)
          except (TypeError, json.JSONDecodeError):
              return False
          tokens = [values.get(key, {}) for key in ("kirocli:social:token", "kirocli:odic:token", "codewhisperer:odic:token")]
          registrations = [values.get(key, {}) for key in ("kirocli:odic:device-registration", "codewhisperer:odic:device-registration")]
          return any(token.get("refresh_token") for token in tokens) and any(
              registration.get("client_id") and registration.get("client_secret") for registration in registrations
          )

      cache_dir = home / ".aws" / "sso" / "cache"
      candidates = [cache_dir / "kiro-auth-token.json"]
      if cache_dir.is_dir():
          candidates.extend(path for path in sorted(cache_dir.glob("*.json")) if path not in candidates)
      for candidate in candidates:
          if candidate.is_file() and usable_json(candidate):
              print(f"json\t{candidate}")
              raise SystemExit

      database = home / ".local" / "share" / "kiro-cli" / "data.sqlite3"
      if database.is_file() and usable_sqlite(database):
          print(f"sqlite\t{database}")
      PY
            }

            if [[ ! -r "$env_file" && -r "$legacy_env" ]]; then
              install -d -m 700 "$config_dir"
              install -m 600 "$legacy_env" "$env_file"
              printf 'Migrated the existing Kiro Gateway environment.\n'
            elif [[ "''${1:-}" == "--if-configured" && ! -r "$env_file" ]]; then
              exit 0
            fi

            install -d -m 700 "$config_dir"
            credential_kind=""
            credential_path=""
            if ! has_configured_credentials; then
              IFS=$'\t' read -r credential_kind credential_path < <(detect_credentials) || true
            fi

            python3 - "$env_file" "$credential_kind" "$credential_path" <<'PY'
      import json
      import os
      import re
      import secrets
      import sys
      import tempfile

      env_path = os.path.abspath(sys.argv[1])
      credential_kind, credential_path = sys.argv[2:]
      try:
          with open(env_path, encoding="utf-8") as file:
              lines = file.readlines()
      except FileNotFoundError:
          lines = []

      values = {}
      positions = {}
      for position, line in enumerate(lines):
          match = re.fullmatch(r"(\s*([A-Z_][A-Z0-9_]*)\s*=\s*)(.*?)\s*\n?", line)
          if not match:
              continue
          value = match.group(3)
          if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
              value = value[1:-1]
          values[match.group(2)] = value
          positions[match.group(2)] = position

      desired = {
          "SERVER_HOST": "127.0.0.1",
          "SERVER_PORT": "8000",
      }
      if not values.get("PROXY_API_KEY"):
          desired["PROXY_API_KEY"] = secrets.token_urlsafe(32)
      if not any(values.get(key) for key in ("REFRESH_TOKEN", "KIRO_CREDS_FILE", "KIRO_CLI_DB_FILE")):
          if credential_kind == "json":
              desired["KIRO_CREDS_FILE"] = credential_path
          elif credential_kind == "sqlite":
              desired["KIRO_CLI_DB_FILE"] = credential_path

      for key, value in desired.items():
          if values.get(key):
              continue
          rendered = f"{key}={json.dumps(value)}\n"
          if key in positions:
              lines[positions[key]] = rendered
          else:
              lines.append(rendered)

      descriptor, temporary_path = tempfile.mkstemp(prefix=".env.", dir=os.path.dirname(env_path))
      try:
          with os.fdopen(descriptor, "w", encoding="utf-8") as file:
              file.writelines(lines)
          os.chmod(temporary_path, 0o600)
          os.replace(temporary_path, env_path)
      except Exception:
          os.unlink(temporary_path)
          raise
      PY

            if ! has_configured_credentials; then
              if [[ "''${1:-}" == "--if-configured" ]]; then
                exit 0
              fi
              printf 'Kiro Gateway environment created, but no usable Kiro IDE or Kiro CLI credentials were found. Log in to either client, then run kiro-gateway-bootstrap again.\n' >&2
              exit 1
            fi

            install -d -m 700 "$data_dir"
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

            rm -f "$configured_marker"
            systemctl --user start kiro-gateway.path
            systemctl --user restart kiro-gateway.service
            systemctl --user start kiro-opencode-model-sync.service
            install -m 600 /dev/null "$configured_marker"
            printf 'Kiro Gateway is configured, running, and synchronized with OpenCode.\n'
    '';
  };
in
{
  home.packages = [ kiroGatewayBootstrap ];

  systemd.user.services.kiro-gateway = {
    Unit = {
      Description = "kiro-gateway: proxy OpenAI/Anthropic-compatible para los modelos de Kiro (usado por opencode)";
      Documentation = "https://github.com/AnthonyNav/kiro-gateway";
      ConditionPathExists = "%h/.config/kiro-gateway/.env";
    };

    Service = {
      WorkingDirectory = "${gatewaySource}";
      # Secretos (PROXY_API_KEY, ruta a las credenciales de Kiro) fuera del
      # store, cargados en runtime desde este archivo.
      EnvironmentFile = "-%h/.config/kiro-gateway/.env";
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
      ConditionPathExists = [
        "%h/.config/kiro-gateway/.env"
        "%h/.local/share/kiro-gateway/venv/bin/python"
      ];
    };

    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe kiroOpenCodeModelSync;
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
