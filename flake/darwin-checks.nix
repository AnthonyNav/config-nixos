{
  inputs,
  lib,
  fleet,
  username,
  pkgs,
}:
let
  # This is a validation fixture, never a deployable inventory entry. Replace
  # it with real host facts only after hostname, user and hardware are known.
  fixture = {
    platform = "darwin";
    system = "aarch64-darwin";
    username = "fleet-test";
    homeDirectory = "/Users/fleet-test";
    kind = "workstation";
    role = "development-workstation";
    desktopStyle = null;
    homeModules = [ ];
    homeProfiles = [
      "development"
      "platform"
      "mobile"
    ];
    capabilities = { };
    connectivity = {
      tailscale = true;
      ssh = false;
      syncthing = true;
    };
    features = {
      graphics = "apple";
    };
    systemModule = _: { };
  };
  testFleet = import ../inventory/fleet.nix {
    hosts = fleet.hosts // {
      macos-test = fixture;
    };
  };
  outputs = import ./hosts.nix {
    inherit inputs username;
    fleet = testFleet;
  };
  darwin = outputs.darwinConfigurations.macos-test;
  home = outputs.homeConfigurations."fleet-test@macos-test";
  facts = import ../ai {
    inherit lib pkgs;
    hostFeatures = fixture.features // fixture // { hostName = "macos-test"; };
    inherit (fixture) homeDirectory;
    rtk = inputs.llm-agents.packages.aarch64-darwin.rtk;
  };
  policy =
    assert outputs.nixosConfigurations ? desktop && outputs.nixosConfigurations ? victus;
    assert !(outputs.nixosConfigurations ? macos-test);
    assert
      builtins.attrNames outputs.darwinConfigurations
      == builtins.sort builtins.lessThan (fleet.darwinHostNames ++ [ "macos-test" ]);
    assert home.config.home.homeDirectory == fixture.homeDirectory;
    assert home.config.fleet.home.profiles == fixture.homeProfiles;
    assert !home.config.wayland.windowManager.hyprland.enable;
    assert
      home.config.launchd.agents.syncthing.enable
      && home.config.launchd.agents.syncthing-fleet-reconcile.enable;
    assert !(home.config.programs.zsh.shellAliases ? pritunl);
    assert !home.config.fleet.development.legacyJupyterLibraries;
    assert facts.facts.os == "macOS" && facts.facts.platform == "aarch64-darwin";
    assert
      lib.hasInfix "# macOS workflow" facts.context && !lib.hasInfix "# NixOS workflow" facts.context;
    assert !darwin.config.services.tailscale.enable;
    assert lib.any (c: c.name == "tailscale-app") darwin.config.homebrew.casks;
    assert lib.all (name: lib.any (c: c.name == name) darwin.config.homebrew.casks) [
        "kitty"
        "hammerspoon"
        "karabiner-elements"
        "aerospace"
      ];
    assert lib.getName home.config.fleet.interaction.backend == "fleet-ui-backend";
    assert
      !lib.any (
        p:
        builtins.elem (lib.getName p) [
          "bubblewrap"
          "nsjail"
          "hyprland"
          "caelestia-shell"
          "kiro-cli"
        ]
      ) home.config.home.packages;
    {
      system = darwin.system.drvPath;
      home = home.activationPackage.drvPath;
    };
in
{
  evaluation =
    builderPkgs:
    assert builtins.deepSeq policy true;
    builderPkgs.runCommand "darwin-evaluation-check" { } ''touch "$out"'';
  native = {
    portable-contracts =
      pkgs.runCommand "darwin-portable-contracts-check"
        {
          nativeBuildInputs = [
            pkgs.python3
            pkgs.git
            pkgs.bash
            pkgs.jq
            pkgs.coreutils
          ];
        }
        ''
          export PYTHONDONTWRITEBYTECODE=1
          python ${../scripts/tests/check-workspace-context.py} ${../scripts/workspace-context.py}
          python ${../scripts/tests/check-portable-workspace.py} ${../scripts}
          bash ${../scripts/tests/check-nix-config.sh} ${../scripts/nix-config.sh}
          touch "$out"
        '';
    darwin-policy =
      assert builtins.deepSeq policy true;
      pkgs.runCommand "darwin-policy-check" { } ''touch "$out"'';
    darwin-system = darwin.system;
    darwin-home = home.activationPackage;
    darwin-ai = facts.bundle;
  };
}
