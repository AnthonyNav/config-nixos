{ lib, pkgs, ... }:

let
  modelCatalogSeed = pkgs.writeText "opencode-kiro-models.json" (
    builtins.toJSON {
      provider.kiro = {
        npm = "@ai-sdk/openai-compatible";
        name = "Kiro Gateway";
        options = {
          baseURL = "http://127.0.0.1:8000/v1";
          apiKey = "{env:PROXY_API_KEY}";
        };
        models = {
          auto.name = "Auto (Kiro elige y ahorra tokens)";
          claude-sonnet-5.name = "Claude Sonnet 5 (preview)";
          "claude-opus-4.8".name = "Claude Opus 4.8 (preview)";
          "claude-opus-4.7".name = "Claude Opus 4.7";
          "claude-opus-4.6".name = "Claude Opus 4.6";
          "claude-sonnet-4.6".name = "Claude Sonnet 4.6";
          "claude-opus-4.5".name = "Claude Opus 4.5";
          "claude-sonnet-4.5".name = "Claude Sonnet 4.5";
          "claude-sonnet-4".name = "Claude Sonnet 4";
          "claude-haiku-4.5".name = "Claude Haiku 4.5";
          "deepseek-3.2".name = "DeepSeek V3.2 (preview)";
          "minimax-m2.5".name = "MiniMax M2.5";
          "minimax-m2.1".name = "MiniMax M2.1 (preview)";
          glm-5.name = "GLM 5";
          qwen3-coder-next.name = "Qwen3 Coder Next (preview)";
        };
      };
      model = "kiro/auto";
      small_model = "kiro/claude-haiku-4.5";
    }
  );

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
  # La configuración base, las skills y el plugin viven en el repo. Kiro se
  # añade como overlay local solo después de su bootstrap exitoso.
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

  # OpenCode merges this mutable Kiro overlay only after a successful bootstrap.
  # It contains model metadata and an environment placeholder, never credentials.
  home.activation.initializeOpenCodeKiroCatalog = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        catalog_dir="$HOME/.local/state/opencode"
        catalog="$catalog_dir/kiro-models.json"
        if [[ ! -e "$catalog" ]]; then
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$catalog_dir"
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 600 ${modelCatalogSeed} "$catalog"
        elif [[ -f "$catalog" ]]; then
          # Upgrade the old models-only catalog without discarding models discovered
          # by a previous gateway synchronization.
          $DRY_RUN_CMD ${pkgs.python3}/bin/python - "$catalog" ${modelCatalogSeed} <<'PY'
    import json
    import os
    import sys
    import tempfile

    catalog_path, seed_path = sys.argv[1:]
    with open(seed_path, encoding="utf-8") as file:
        seed = json.load(file)
    try:
        with open(catalog_path, encoding="utf-8") as file:
            catalog = json.load(file)
    except (OSError, json.JSONDecodeError):
        catalog = {}

    catalog.setdefault("provider", {})
    existing = catalog["provider"].setdefault("kiro", {})
    defaults = seed["provider"]["kiro"]
    for key in ("npm", "name", "options"):
        existing[key] = defaults[key]
    models = existing.setdefault("models", {})
    for model_id, model in defaults["models"].items():
        models.setdefault(model_id, model)
    catalog.setdefault("model", seed["model"])
    catalog.setdefault("small_model", seed["small_model"])

    descriptor, temporary_path = tempfile.mkstemp(prefix=".kiro-models.", dir=os.path.dirname(catalog_path))
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as file:
            json.dump(catalog, file, indent=2)
            file.write("\n")
        os.chmod(temporary_path, 0o600)
        os.replace(temporary_path, catalog_path)
    except Exception:
        os.unlink(temporary_path)
        raise
    PY
        fi
  '';
}
