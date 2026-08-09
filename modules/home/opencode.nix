{ lib, pkgs, ... }:

{
  # Las skills comunes viven en el repo y Home Manager las distribuye a cada
  # workstation. config.json queda fuera de Nix porque contiene el secreto de
  # Kiro específico de cada equipo.
  xdg.configFile = {
    "opencode/skills/graphify/SKILL.md".source = ../../opencode/skills/graphify/SKILL.md;
    "opencode/skills/pre-pr-review/SKILL.md".source = ../../opencode/skills/pre-pr-review/SKILL.md;
    "opencode/plugins/rtk.js".source = ../../opencode/plugins/rtk.js;
  };

  home.activation.migrateOpenCodeSkills = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
    # Estos eran los únicos artefactos locales que ahora administra el perfil.
    # No se toca config.json ni ningún secreto de OpenCode.
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -rf \
      "$HOME/.claude/skills/graphify" \
      "$HOME/.config/opencode/skills/pre-pr-review" \
      "$HOME/.config/opencode/plugins/rtk.ts" \
      "$HOME/.config/opencode/node_modules" \
      "$HOME/.config/opencode/package.json" \
      "$HOME/.config/opencode/package-lock.json"
  '';
}
