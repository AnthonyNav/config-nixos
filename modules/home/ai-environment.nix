{
  config,
  lib,
  pkgs,
  aiToolsPackages,
  hostFeatures,
  ...
}:
let
  cfg = config.fleet.ai;
  environment = import ../../ai {
    inherit lib pkgs hostFeatures;
    inherit (config.home) homeDirectory;
    rtk = aiToolsPackages.rtk;
    enabled = cfg.enable;
  };
  python = "${pkgs.python3}/bin/python3";
  manager = ../../scripts/ai-environment.py;
  command =
    action:
    lib.escapeShellArgs [
      python
      (toString manager)
      action
      "--home"
      config.home.homeDirectory
      "--bundle"
      (toString environment.bundle)
    ];
  doctor = pkgs.writeShellApplication {
    name = "ai-doctor";
    text = ''exec ${command "doctor"} "$@"'';
  };
  skillLinks = lib.listToAttrs (
    lib.concatMap (
      name:
      map
        (root: {
          name = "${root}/${name}/SKILL.md";
          value.source = ../../ai/skills + "/${name}/SKILL.md";
        })
        [
          ".codex/skills"
          ".claude/skills"
          ".kiro/skills"
        ]
    ) environment.skillNames
  );
in
{
  options.fleet.ai = {
    enable = lib.mkEnableOption "shared fleet AI context, skills and adapters";
    bundle = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = "Evaluated, credential-free AI environment for diagnostics and checks.";
    };
  };
  config = {
    fleet.ai.bundle = environment.bundle;
    home.packages = lib.optional cfg.enable doctor;
    home.file = lib.mkIf cfg.enable (
      skillLinks
      // {
        ".claude/rules/nixos-fleet.md".text = environment.context;
        ".kiro/steering/nixos-fleet.md".text = "---\ninclusion: always\n---\n\n" + environment.context;
        ".kiro/agents/nixos-fleet.json".text = builtins.toJSON environment.kiroAgent;
      }
    );
    # Mutable app settings stay user-owned. Validate all target files first,
    # then reconcile only our recorded entries after Home Manager links files.
    home.activation.checkFleetAi = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
      ${command "check"}
    '';
    home.activation.reconcileFleetAi =
      lib.hm.dag.entryAfter
        [
          "linkGeneration"
          "cleanupLegacyClaudeSettings"
        ]
        ''
          run ${command "apply"}
        '';
  };
}
