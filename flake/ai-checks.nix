{
  lib,
  pkgs,
  self,
  fleet,
  username,
  aiToolsPackages,
}:
let
  baseArgs = {
    inherit lib pkgs;
    hostFeatures = fleet.hosts.thinkpad.features // fleet.hosts.thinkpad // { hostName = "thinkpad"; };
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
  rejects = args: !(builtins.tryEval ((import ../ai (baseArgs // args)).selected)).success;
  bundles = lib.genAttrs fleet.workstationNames (
    name: self.homeConfigurations."${username}@${name}".config.fleet.ai.bundle
  );
  fixtures = pkgs.writeText "ai-fixtures.json" (
    builtins.toJSON {
      hosts = builtins.mapAttrs (_: b: toString b) bundles;
      inventory = fleet.inventory;
      enabled = toString enabled.bundle;
    }
  );
  python = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);
in
{
  ai-environment =
    assert rejects { registry = registry ++ registry; };
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
          ${bundles.thinkpad} ${aiToolsPackages.rtk}/bin/rtk
        python ${../scripts/tests/check-ai-bundles.py} ${fixtures}
        touch "$out"
      '';
}
