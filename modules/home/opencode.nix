{ lib, pkgs, ... }:

let
  opencodeWithKiro = pkgs.writeShellApplication {
    name = "opencode";
    runtimeInputs = [
      pkgs.opencode
      pkgs.python3
    ];
    text = ''
            gateway_env="''${XDG_CONFIG_HOME:-$HOME/.config}/kiro-gateway/.env"
            data_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/kiro-gateway"
            catalog="$HOME/.local/state/opencode/kiro-models.json"

            # Kiro is loaded only after a successful bootstrap. Do not execute .env as shell code.
            if [[ -f "$data_dir/configured" && -r "$gateway_env" && -r "$catalog" ]]; then
              proxy_api_key="$(python3 - "$gateway_env" <<'PY'
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
              if [[ -n "$proxy_api_key" ]]; then
                export PROXY_API_KEY="$proxy_api_key"
                export OPENCODE_CONFIG="$catalog"
              fi
            fi

            exec ${lib.getExe pkgs.opencode} "$@"
    '';
  };
in

{
  # La configuración base incluye el provider Kiro sin hacerlo predeterminado.
  # El wrapper solo expone su credencial y catálogo después del bootstrap.
  xdg.configFile = {
    "opencode/opencode.json".source = ../../opencode/opencode.json;
    "opencode/agents" = {
      source = ../../opencode/agents;
      recursive = true;
    };
    "opencode/commands" = {
      source = ../../opencode/commands;
      recursive = true;
    };
    "opencode/skills" = {
      source = ../../opencode/skills;
      recursive = true;
    };
    "opencode/plugins/rtk.js".source = ../../opencode/plugins/rtk.js;
  };

  home.packages = [ opencodeWithKiro ];

  home.activation.migrateOpenCodeSkills = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
    # Estos eran los artefactos locales que ahora administra el perfil.
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -rf \
      "$HOME/.claude/skills/graphify" \
      "$HOME/.config/opencode/plugins/rtk.ts" \
      "$HOME/.config/opencode/node_modules" \
      "$HOME/.config/opencode/package.json" \
      "$HOME/.config/opencode/package-lock.json"

    # Remove the old whole-directory link before switching to recursive links.
    if [[ -L "$HOME/.config/opencode/skills" ]]; then
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -f "$HOME/.config/opencode/skills"
    else
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -rf "$HOME/.config/opencode/skills/pre-pr-review"
    fi
  '';

}
