{
  aiToolsPackages,
  lib,
  pkgs,
  ...
}:

let
  opencodePackages = import ./opencode-packages.nix {
    inherit lib pkgs;
    opencodePackage = aiToolsPackages.opencode;
  };
in

{
  # La configuración base incluye el provider Kiro sin hacerlo predeterminado.
  # El wrapper solo expone su credencial y catálogo después del bootstrap.
  xdg.configFile = {
    "opencode/opencode.json".source = ../../opencode/opencode.json;
    "opencode/skills/graphify/SKILL.md".source = ../../opencode/skills/graphify/SKILL.md;
    "opencode/skills/pre-pr-review/SKILL.md".source = ../../opencode/skills/pre-pr-review/SKILL.md;
    "opencode/skills/nixos-maintenance/SKILL.md".source =
      ../../opencode/skills/nixos-maintenance/SKILL.md;
    "opencode/skills/network-diagnostics/SKILL.md".source =
      ../../opencode/skills/network-diagnostics/SKILL.md;
    "opencode/skills/risk-classification/SKILL.md".source =
      ../../opencode/skills/risk-classification/SKILL.md;
    "opencode/skills/task-contract/SKILL.md".source = ../../opencode/skills/task-contract/SKILL.md;
    "opencode/plugins/rtk.js".source = ../../opencode/plugins/rtk.js;
  };

  home.packages = [
    opencodePackages.default
    opencodePackages.workflow
  ];

  # Fail safely instead of deleting user-owned state during activation.
  home.activation.checkLegacyOpenCodeArtifacts = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
    legacy_paths=(
      "$HOME/.claude/skills/graphify"
      "$HOME/.config/opencode/plugins/rtk.ts"
    )

    for path in "''${legacy_paths[@]}"; do
      if [[ -e "$path" || -L "$path" ]]; then
        errorEcho "Legacy OpenCode artifact blocks activation: $path"
        errorEcho "Review and remove or archive it manually, then run Home Manager again."
        exit 1
      fi
    done
  '';
}
