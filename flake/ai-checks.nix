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
    rtk = aiToolsPackages.rtk;
  };
  registry = import ../ai/mcp/registry.nix;
  policy = {
    defaults = {
      codex = [ "openai-docs" ];
      claude = [ "openai-docs" ];
      kiro = [ "openai-docs" ];
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
    requiredSecrets = [ ];
    harnesses = [
      "codex"
      "claude"
      "kiro"
    ];
    defaultEnabled = false;
    trust = "Test fixture only";
  };
  localArgs = {
    registry = registry ++ [ localEntry ];
    policy = {
      defaults = lib.genAttrs [ "codex" "claude" "kiro" ] (_: [
        "openai-docs"
        "artemis"
      ]);
      hosts = { };
    };
  };
  localEnabled = import ../ai (baseArgs // localArgs);
  rejects = args: !(builtins.tryEval ((import ../ai (baseArgs // args)).selected)).success;
  bundles = lib.genAttrs fleet.workstationNames (
    name: self.homeConfigurations."${username}@${name}".config.fleet.ai.bundle
  );
  fixtures = pkgs.writeText "ai-fixtures.json" (
    builtins.toJSON {
      hosts = builtins.mapAttrs (_: b: toString b) bundles;
      inventory = fleet.inventory;
      enabled = toString enabled.bundle;
      localEnabled = toString localEnabled.bundle;
    }
  );
  python = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);
in
{
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
          ${../scripts/ai-environment.py} ${../scripts/ai-rtk-hook.py} \
          ${bundles.${representative}} ${aiToolsPackages.rtk}/bin/rtk
        python ${../scripts/tests/check-ai-bundles.py} ${fixtures}
        python ${../scripts/tests/check-artemis.py} ${../scripts/artemis.py}
        touch "$out"
      '';
}
