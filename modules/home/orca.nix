{
  config,
  lib,
  pkgs,
  ...
}:
let
  skill = ../../ai/orca/skills/fleet-orca-workspaces/SKILL.md;
  skillName = "fleet-orca-workspaces";
  skillRoots = [
    ".agents/skills"
    ".codex/skills"
    ".claude/skills"
    ".kiro/skills"
  ];
in
{
  options.fleet.ai.orca.enable = lib.mkEnableOption "the optional Orca desktop pilot";

  config = lib.mkIf config.fleet.ai.orca.enable {
    home.packages = [ (pkgs.callPackage ../../packages/orca-ide.nix { }) ];
    home.file = lib.listToAttrs (
      map (root: {
        name = "${root}/${skillName}/SKILL.md";
        value.source = skill;
      }) skillRoots
    );
  };
}
