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
    "opencode"
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
          "context"
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
    && builtins.elem entry.context [
      "any"
      "work"
      "personal"
    ]
    && builtins.elem entry.authentication [
      "none"
      "oauth"
      "runtime-env"
      "runtime-file"
    ]
    && builtins.isList entry.requiredSecrets
    && lib.all (
      name: builtins.isString name && builtins.match "[A-Z][A-Z0-9_]*" name != null
    ) entry.requiredSecrets
    && builtins.length entry.requiredSecrets == builtins.length (lib.unique entry.requiredSecrets)
    && (
      if
        builtins.elem entry.authentication [
          "none"
          "oauth"
        ]
      then
        entry.requiredSecrets == [ ]
      else
        entry.requiredSecrets != [ ] && entry.context != "any"
    )
    && (
      entry.transport != "http"
      || !builtins.elem entry.authentication [
        "runtime-env"
        "runtime-file"
      ]
      || entry.requiredSecrets == [ "API_ACCESS_TOKEN" ]
    )
    && lib.all (h: builtins.elem h harnesses) entry.harnesses;
  validSelection =
    harness: names:
    builtins.length names == builtins.length (lib.unique names)
    && lib.all (
      name:
      builtins.hasAttr name catalog
      && builtins.elem harness catalog.${name}.harnesses
      # Native HTTP OAuth can only be shared intentionally across contexts.
      # Restricted OAuth needs a transport-specific runtime adapter; cataloging
      # it does not silently make an unsupported connection eligible.
      && !(
        catalog.${name}.transport == "http"
        && catalog.${name}.authentication == "oauth"
        && catalog.${name}.context != "any"
      )
    ) names;
  facts = {
    os = "NixOS";
    host = hostFeatures.hostName;
    platform = hostFeatures.system;
    inherit (hostFeatures) kind;
    inherit (hostFeatures) role;
    capabilities = hostFeatures.capabilities // {
      virtualization = hostFeatures.virtualization.enable or false;
      gpuCompute = hostFeatures.gpuCompute.enable or false;
    };
    graphics = hostFeatures.graphics or "none";
    inherit (hostFeatures) connectivity;
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
      ".agents/skills"
    ]
  ) skillNames;
  hookCommand = lib.escapeShellArgs [
    "${pkgs.python3}/bin/python3"
    "${../scripts/ai-rtk-hook.py}"
    "${rtk}/bin/rtk"
  ];
  workspaceTools = import ../packages/workspace-tools.nix { inherit pkgs lib homeDirectory; };
  contextFile = pkgs.writeText "fleet-context.md" context;
  connection =
    id:
    let
      entry = catalog.${id};
      guarded =
        entry.transport == "stdio"
        || entry.context != "any"
        || builtins.elem entry.authentication [
          "runtime-env"
          "runtime-file"
        ];
      metadata = pkgs.writeText "mcp-${id}.json" (builtins.toJSON entry);
      guard = pkgs.writeShellScript "mcp-${id}-context" ''
        exec ${pkgs.python3}/bin/python3 -B ${../scripts}/mcp-context.py \
          --policy ${workspaceTools.configuration} --entry ${metadata}${
            lib.optionalString (entry.transport == "http") " --proxy ${lib.getExe pkgs.mcp-proxy}"
          }
      '';
    in
    if guarded then
      {
        command = toString guard;
        args = [ ];
      }
    else
      { inherit (entry) url; };
  connections =
    harness:
    lib.listToAttrs (
      map (id: {
        name = "fleet-${id}";
        value =
          let
            value = connection id;
          in
          if harness == "opencode" then
            if value ? command then
              {
                type = "local";
                command = [ value.command ] ++ value.args;
                enabled = true;
              }
            else
              {
                type = "remote";
                inherit (value) url;
                enabled = true;
              }
          else
            value
            // lib.optionalAttrs (harness == "claude") { type = if value ? command then "stdio" else "http"; };
      }) selected.${harness}
    );
  codexConfig = lib.concatMapStringsSep "\n" (
    id:
    let
      value = connection id;
    in
    ''
      [mcp_servers."fleet-${id}"]
      ${
        if value ? command then
          ''
            command = ${builtins.toJSON value.command}
            args = ${builtins.toJSON value.args}
          ''
        else
          "url = ${builtins.toJSON value.url}"
      }
    ''
  ) selected.codex;
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
  opencodeOverlay = {
    instructions = lib.optional enabled (toString contextFile);
    mcp = connections "opencode";
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
    opencodeOverlay
    ;
  bundle = pkgs.linkFarm "nixos-ai-${facts.host}" [
    {
      name = "context.md";
      path = contextFile;
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
    (jsonFile "opencode-overlay.json" opencodeOverlay)
    {
      name = "workspace-policy.json";
      path = workspaceTools.configuration;
    }
  ];
}
