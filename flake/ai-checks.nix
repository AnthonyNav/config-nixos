{
  lib,
  pkgs,
  self,
  fleet,
  username,
  aiToolsPackages,
}:
let
  representative = builtins.head fleet.workstationNames;
  baseArgs = {
    inherit lib pkgs;
    hostFeatures =
      fleet.hosts.${representative}.features
      // fleet.hosts.${representative}
      // {
        hostName = representative;
      };
    homeDirectory = "/home/${username}";
    inherit (aiToolsPackages) rtk;
  };
  registry = import ../ai/mcp/registry.nix;
  policy = {
    defaults = {
      codex = [ "openai-docs" ];
      claude = [ "openai-docs" ];
      kiro = [ "openai-docs" ];
      opencode = [ "openai-docs" ];
    };
    hosts = { };
  };
  enabled = import ../ai (baseArgs // { inherit policy; });
  localEntry = {
    id = "artemis";
    owner = "Google";
    source = "https://github.com/google/artemis";
    transport = "stdio";
    command = "${pkgs.writeShellScript "artemis-fixture" "exit 1"}";
    args = [ "mcp" ];
    authentication = "none";
    context = "any";
    requiredSecrets = [ ];
    harnesses = [
      "codex"
      "claude"
      "kiro"
      "opencode"
    ];
    defaultEnabled = false;
    trust = "Test fixture only";
  };
  localArgs = {
    registry = registry ++ [ localEntry ];
    policy = {
      defaults = lib.genAttrs [ "codex" "claude" "kiro" "opencode" ] (_: [
        "openai-docs"
        "artemis"
      ]);
      hosts = { };
    };
  };
  localEnabled = import ../ai (baseArgs // localArgs);
  guardedEntry = localEntry // {
    id = "work-fixture";
    context = "work";
    authentication = "runtime-env";
    requiredSecrets = [ "TEST_TOKEN" ];
  };
  guardedEnabled = import ../ai (
    baseArgs
    // {
      registry = registry ++ [ guardedEntry ];
      policy = {
        defaults = lib.genAttrs [ "codex" "claude" "kiro" "opencode" ] (_: [ "work-fixture" ]);
        hosts = { };
      };
    }
  );
  rejects = args: !(builtins.tryEval (import ../ai (baseArgs // args)).selected).success;
  bundles = lib.genAttrs fleet.workstationNames (
    name: self.homeConfigurations."${username}@${name}".config.fleet.ai.bundle
  );
  fixtures = pkgs.writeText "ai-fixtures.json" (
    builtins.toJSON {
      hosts = builtins.mapAttrs (_: toString) bundles;
      inherit (fleet) inventory;
      enabled = toString enabled.bundle;
      localEnabled = toString localEnabled.bundle;
      guardedEnabled = toString guardedEnabled.bundle;
    }
  );
  python = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);
  systems = map (name: self.nixosConfigurations.${name}.config) fleet.workstationNames;
  remoteFixture = self.nixosConfigurations.${representative}.extendModules {
    specialArgs.hostFeatures = baseArgs.hostFeatures // {
      orcaRemote.mode = "desktop-app";
    };
  };
  headlessFixture = self.nixosConfigurations.${representative}.extendModules {
    specialArgs.hostFeatures = baseArgs.hostFeatures // {
      orcaRemote.mode = "headless";
    };
  };
  antigravityFixture = self.nixosConfigurations.${representative}.extendModules {
    modules = [ { fleet.agentRuntime.antigravityCli = true; } ];
  };
  offFixture = self.nixosConfigurations.${representative}.extendModules {
    specialArgs.hostFeatures = baseArgs.hostFeatures // {
      orcaRemote.mode = "off";
    };
  };
  endpoints = import ../inventory/endpoints.nix { };
  remoteFleet = import ../inventory/fleet.nix {
    hosts = fleet.hosts // {
      ${representative} = fleet.hosts.${representative} // {
        features = fleet.hosts.${representative}.features // {
          orcaRemote.mode = "desktop-app";
        };
      };
    };
  };
  remoteEndpoints = import ../inventory/endpoints.nix { fleet = remoteFleet; };
in
{
  agent-runtime-policy =
    assert lib.all (
      system:
      builtins.elem pkgs.bubblewrap system.environment.systemPackages
      && builtins.elem pkgs.socat system.environment.systemPackages
    ) systems;
    assert lib.all (
      name:
      let
        system = self.nixosConfigurations.${name}.config;
        enabled = (fleet.hosts.${name}.features.orcaRemote.mode or "off") == "desktop-app";
      in
      (builtins.elem endpoints.ports.orca system.networking.firewall.interfaces.tailscale0.allowedTCPPorts)
      == enabled
    ) fleet.workstationNames;
    assert
      !(builtins.elem endpoints.ports.orca offFixture.config.networking.firewall.interfaces.tailscale0.allowedTCPPorts);
    assert builtins.elem pkgs.nsjail antigravityFixture.config.environment.systemPackages;
    assert builtins.elem endpoints.ports.orca
      remoteFixture.config.networking.firewall.interfaces.tailscale0.allowedTCPPorts;
    assert
      !(builtins.elem endpoints.ports.orca remoteFixture.config.networking.firewall.allowedTCPPorts);
    assert !(builtins.tryEval headlessFixture.config.system.build.toplevel.drvPath).success;
    assert
      (builtins.any (endpoint: endpoint.name == "orca") endpoints.tailnet)
      == (fleet.orcaRemoteHostNames != [ ]);
    assert
      (lib.findFirst (endpoint: endpoint.name == "orca") null remoteEndpoints.tailnet).hosts
      == lib.sort builtins.lessThan (lib.unique (fleet.orcaRemoteHostNames ++ [ representative ]));
    assert remoteEndpoints.public == [ ];
    pkgs.runCommand "agent-runtime-policy-check" { } ''touch "$out"'';
  ai-environment =
    assert rejects { registry = registry ++ registry; };
    assert rejects (
      localArgs // { registry = registry ++ [ (localEntry // { command = "/tmp/unmanaged"; }) ]; }
    );
    assert rejects (localArgs // { registry = registry ++ [ (localEntry // { args = "mcp"; }) ]; });
    assert rejects (
      localArgs // { registry = registry ++ [ (localEntry // { env.SECRET = "forbidden"; }) ]; }
    );
    assert rejects {
      policy.defaults = {
        codex = [ "missing" ];
        claude = [ ];
        kiro = [ ];
      };
      policy.hosts = { };
    };
    assert rejects {
      inherit policy;
      registry = map (
        entry:
        entry
        // {
          authentication = "runtime";
          requiredSecrets = [ "API_TOKEN" ];
        }
      ) registry;
    };
    pkgs.runCommand "ai-environment-check"
      {
        nativeBuildInputs = [
          python
          pkgs.git
        ];
      }
      ''
        export XDG_CONFIG_HOME="$TMPDIR/config"
        export XDG_CACHE_HOME="$TMPDIR/cache"
        export XDG_DATA_HOME="$TMPDIR/data"
        mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME"
        python ${../scripts/tests/check-ai-environment.py} \
          ${../scripts}/ai-environment.py ${../scripts/ai-rtk-hook.py} \
          ${bundles.${representative}} ${aiToolsPackages.rtk}/bin/rtk
        python ${../scripts/tests/check-ai-bundles.py} ${fixtures}
        python ${../scripts/tests/check-ai-runtime.py} ${../scripts}
        python ${../scripts/tests/check-artemis.py} ${../scripts/artemis.py}
        touch "$out"
      '';
}
