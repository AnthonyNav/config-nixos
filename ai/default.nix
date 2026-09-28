{
  lib,
  pkgs,
  hostFeatures,
  homeDirectory,
  rtk,
  enabled ? true,
  registry ? import ./mcp/registry.nix,
  policy ? import ./mcp/policy.nix,
}:
let
  harnesses = [
    "codex"
    "claude"
    "kiro"
  ];
  ids = map (entry: entry.id) registry;
  catalog = builtins.listToAttrs (
    map (entry: {
      name = entry.id;
      value = entry;
    }) registry
  );
  selected = lib.genAttrs harnesses (
    harness:
    if !enabled then
      [ ]
    else
      policy.hosts.${hostFeatures.hostName}.${harness} or policy.defaults.${harness}
  );
  validEntry =
    entry:
    (
      builtins.attrNames entry == builtins.sort builtins.lessThan (
        [
          "authentication"
          "defaultEnabled"
          "harnesses"
          "id"
          "owner"
          "requiredSecrets"
          "source"
          "transport"
          "trust"
        ]
        ++ (
          if entry.transport == "stdio" then
            [
              "command"
              "args"
            ]
          else
            [ "url" ]
        )
      )
    )
    && builtins.match "[a-z][a-z0-9-]*" entry.id != null
    && (
      if entry.transport == "http" then
        builtins.match "https://[A-Za-z0-9.-]+(:[0-9]+)?(/[A-Za-z0-9_./-]*)?" entry.url != null
      else if entry.transport == "stdio" then
        builtins.isString entry.command
        && builtins.match "/nix/store/[A-Za-z0-9+._/-]+" entry.command != null
        && builtins.isList entry.args
        && lib.all builtins.isString entry.args
      else
        false
    )
    && entry.defaultEnabled == false
    && lib.all (h: builtins.elem h harnesses) entry.harnesses;
  validSelection =
    harness: names:
    builtins.length names == builtins.length (lib.unique names)
    && lib.all (
      name:
      builtins.hasAttr name catalog
      && builtins.elem harness catalog.${name}.harnesses
      && catalog.${name}.authentication == "none"
      && catalog.${name}.requiredSecrets == [ ]
    ) names;
  facts = {
    os = "NixOS";
    host = hostFeatures.hostName;
    platform = hostFeatures.system;
    kind = hostFeatures.kind;
    role = hostFeatures.role;
    capabilities = hostFeatures.capabilities // {
      virtualization = hostFeatures.virtualizationLab.enable or false;
      gpuCompute = hostFeatures.gpuCompute.enable or false;
    };
    graphics = hostFeatures.graphics or "none";
    connectivity = hostFeatures.connectivity;
  };
  context =
    builtins.readFile ./context/global.md
    + "\n"
    + builtins.readFile ./context/nixos.md
    + "\n# Evaluated host facts\n\n"
    + lib.concatStringsSep "\n" [
      "OS: ${facts.os}"
      "Host: ${facts.host}"
      "Platform: ${facts.platform}"
      "Kind: ${facts.kind}"
      "Role: ${facts.role}"
      "Graphics: ${facts.graphics}"
      "Capabilities (eligibility): ${builtins.toJSON facts.capabilities}"
      "Connectivity policy: ${builtins.toJSON facts.connectivity}"
    ]
    + "\n";
  skillNames = builtins.attrNames (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./skills)
  );
  skillFiles = lib.concatMap (
    name:
    map (root: "${root}/${name}/SKILL.md") [
      ".codex/skills"
      ".claude/skills"
      ".kiro/skills"
    ]
  ) skillNames;
  hookCommand = lib.escapeShellArgs [
    "${pkgs.python3}/bin/python3"
    "${../scripts/ai-rtk-hook.py}"
    "${rtk}/bin/rtk"
  ];
  connections =
    harness:
    lib.listToAttrs (
      map (id: {
        name = "fleet-${id}";
        value =
          if catalog.${id}.transport == "stdio" then
            (lib.optionalAttrs (harness == "claude") { type = "stdio"; })
            // {
              inherit (catalog.${id}) command args;
            }
          else
            (lib.optionalAttrs (harness == "claude") { type = "http"; })
            // {
              url = catalog.${id}.url;
            };
      }) selected.${harness}
    );
  codexConfig = lib.concatMapStringsSep "\n" (id: ''
    [mcp_servers."fleet-${id}"]
    ${
      if catalog.${id}.transport == "stdio" then
        ''
          command = ${builtins.toJSON catalog.${id}.command}
          args = ${builtins.toJSON catalog.${id}.args}
        ''
      else
        "url = ${builtins.toJSON catalog.${id}.url}"
    }
  '') selected.codex;
  mcpEntries =
    harness: root:
    lib.mapAttrsToList (name: value: {
      path = [
        root
        name
      ];
      kind = "set";
      inherit value;
    }) (connections harness);
  manifest = {
    text =
      lib.optionalAttrs enabled {
        ".codex/AGENTS.md" = context;
      }
      // lib.optionalAttrs (selected.codex != [ ]) {
        ".codex/config.toml" = codexConfig;
      };
    json =
      lib.optionalAttrs enabled {
        ".claude/settings.json" = [
          {
            path = [
              "hooks"
              "PreToolUse"
            ];
            kind = "append";
            value = [
              {
                matcher = "Bash";
                hooks = [
                  {
                    type = "command";
                    command = hookCommand;
                    timeout = 5;
                  }
                ];
              }
            ];
          }
        ];
      }
      // lib.optionalAttrs (selected.claude != [ ]) {
        ".claude.json" = mcpEntries "claude" "mcpServers";
      }
      // lib.optionalAttrs (selected.kiro != [ ]) {
        ".kiro/settings/mcp.json" = mcpEntries "kiro" "mcpServers";
      };
  };
  files =
    if enabled then
      skillFiles
      ++ [
        ".claude/rules/nixos-fleet.md"
        ".kiro/steering/nixos-fleet.md"
        ".kiro/agents/nixos-fleet.json"
      ]
    else
      [ ];
  kiroAgent = {
    name = "nixos-fleet";
    description = "NixOS fleet context and shared maintenance skills";
    prompt = "Use the supplied fleet context and relevant skills. Respect the current project's instructions.";
    resources = [
      "file://${homeDirectory}/.kiro/steering/nixos-fleet.md"
      "file://.kiro/steering/**/*.md"
      "file://AGENTS.md"
      "skill://${homeDirectory}/.kiro/skills/fleet-*/SKILL.md"
    ];
    tools = [ "*" ];
    allowedTools = [ ];
    mcpServers = connections "kiro";
  };
  jsonFile = name: value: {
    inherit name;
    path = pkgs.writeText name (builtins.toJSON value);
  };
in
assert builtins.length ids == builtins.length (lib.unique ids);
assert lib.all validEntry registry;
assert lib.all (h: validSelection h selected.${h}) harnesses;
{
  inherit
    facts
    context
    skillNames
    manifest
    files
    kiroAgent
    selected
    ;
  bundle = pkgs.linkFarm "nixos-ai-${facts.host}" ([
    {
      name = "context.md";
      path = pkgs.writeText "fleet-context.md" context;
    }
    {
      name = "skills";
      path = ./skills;
    }
    (jsonFile "host.json" facts)
    (jsonFile "registry.json" registry)
    (jsonFile "enabled.json" selected)
    (jsonFile "manifest.json" manifest)
    (jsonFile "files.json" files)
    (jsonFile "kiro-agent.json" kiroAgent)
  ]);
}
