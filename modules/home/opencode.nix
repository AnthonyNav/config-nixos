{ lib, pkgs, ... }:

let
  modelCatalogSeed = pkgs.writeText "opencode-kiro-models.json" (
    builtins.toJSON {
      provider.kiro.models = { };
    }
  );

  opencodeWithKiro = pkgs.writeShellApplication {
    name = "opencode";
    runtimeInputs = [ pkgs.opencode ];
    text = ''
      gateway_env="''${XDG_CONFIG_HOME:-$HOME/.config}/kiro-gateway/.env"
      if [[ ! -r "$gateway_env" ]]; then
        printf 'OpenCode requires a readable Kiro Gateway environment file: %s\n' "$gateway_env" >&2
        exit 1
      fi

      # Read only the proxy credential in a subprocess; Kiro credentials stay private.
      proxy_api_key="$(
        set -a
        # shellcheck source=/dev/null
        source "$gateway_env"
        printf '%s' "$PROXY_API_KEY"
      )"
      if [[ -z "$proxy_api_key" ]]; then
        printf 'PROXY_API_KEY is missing from %s\n' "$gateway_env" >&2
        exit 1
      fi

      export PROXY_API_KEY="$proxy_api_key"
      export OPENCODE_CONFIG="$HOME/.local/state/opencode/kiro-models.json"
      exec ${lib.getExe pkgs.opencode} "$@"
    '';
  };
in

{
  # La configuración base, las skills y el plugin viven en el repo. La clave de
  # Kiro se resuelve en runtime desde el .env privado del gateway.
  xdg.configFile = {
    "opencode/opencode.json".source = ../../opencode/opencode.json;
    "opencode/skills/graphify/SKILL.md".source = ../../opencode/skills/graphify/SKILL.md;
    "opencode/skills/pre-pr-review/SKILL.md".source = ../../opencode/skills/pre-pr-review/SKILL.md;
    "opencode/skills/nixos-maintenance/SKILL.md".source =
      ../../opencode/skills/nixos-maintenance/SKILL.md;
    "opencode/skills/network-diagnostics/SKILL.md".source =
      ../../opencode/skills/network-diagnostics/SKILL.md;
    "opencode/plugins/rtk.js".source = ../../opencode/plugins/rtk.js;
  };

  home.packages = [ opencodeWithKiro ];

  home.activation.migrateOpenCodeSkills = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
    # Estos eran los artefactos locales que ahora administra el perfil.
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -rf \
      "$HOME/.claude/skills/graphify" \
      "$HOME/.config/opencode/skills/pre-pr-review" \
      "$HOME/.config/opencode/plugins/rtk.ts" \
      "$HOME/.config/opencode/node_modules" \
      "$HOME/.config/opencode/package.json" \
      "$HOME/.config/opencode/package-lock.json"
  '';

  # OpenCode merges this mutable catalog after the Nix-managed base config.
  # It only contains discovered model metadata, never credentials.
  home.activation.initializeOpenCodeKiroCatalog = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    catalog_dir="$HOME/.local/state/opencode"
    catalog="$catalog_dir/kiro-models.json"
    if [[ ! -e "$catalog" ]]; then
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$catalog_dir"
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 600 ${modelCatalogSeed} "$catalog"
    fi
  '';
}
