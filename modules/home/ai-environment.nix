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
  artemis = import ../../packages/artemis.nix { inherit pkgs lib; };
  basePolicy = import ../../ai/mcp/policy.nix;
  artemisSelected = harness: builtins.elem harness cfg.artemis.harnesses;
  policy = basePolicy // {
    hosts = basePolicy.hosts // {
      ${hostFeatures.hostName} = lib.genAttrs [ "codex" "claude" "kiro" ] (
        h:
        (basePolicy.hosts.${hostFeatures.hostName}.${h} or basePolicy.defaults.${h})
        ++ lib.optional (cfg.artemis.enable && artemisSelected h) "artemis"
      );
    };
  };
  environment = import ../../ai {
    inherit lib pkgs hostFeatures;
    inherit (config.home) homeDirectory;
    inherit (aiToolsPackages) rtk;
    enabled = cfg.enable;
    inherit policy;
    registry =
      import ../../ai/mcp/registry.nix
      ++ lib.optional cfg.artemis.enable {
        id = "artemis";
        owner = "Google";
        source = "https://github.com/google/artemis";
        transport = "stdio";
        command = "${artemis}/bin/fleet-artemis";
        args = [ "mcp" ];
        authentication = "none";
        requiredSecrets = [ ];
        harnesses = [
          "codex"
          "claude"
          "kiro"
        ];
        defaultEnabled = false;
        trust = "Local Android automation with external model calls; test devices/data only. Provider credentials stay in runtime state.";
      };
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
    artemis = {
      enable = lib.mkEnableOption "optional Artemis launcher (no preparation or MCP connection automatically)";
      harnesses = lib.mkOption {
        type = lib.types.listOf (
          lib.types.enum [
            "codex"
            "claude"
            "kiro"
          ]
        );
        default = [ ];
        description = "Assistants explicitly allowed to start the optional Artemis MCP server.";
      };
    };
    bundle = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = "Evaluated, credential-free AI environment for diagnostics and checks.";
    };
  };
  config = {
    fleet.ai.bundle = environment.bundle;
    assertions = [
      {
        assertion = cfg.artemis.harnesses == [ ] || (cfg.enable && cfg.artemis.enable);
        message = "Artemis MCP harnesses require both fleet.ai.enable and fleet.ai.artemis.enable.";
      }
    ];
    home.packages = lib.optional cfg.enable doctor ++ lib.optional cfg.artemis.enable artemis;
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
