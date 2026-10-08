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
    assert home.config.launchd.agents.workspace-sync.enable;
    assert home.config.launchd.agents.workspace-sync.config.StartInterval == 120;
    assert !(home.config.programs.zsh.shellAliases ? pritunl);
    assert lib.all (name: lib.any (package: lib.getName package == name) home.config.home.packages) [
      "ripgrep"
      "jq"
      "fd"
      "fleet-macos-readiness"
    ];
    assert !home.config.fleet.development.legacyJupyterLibraries;
    assert facts.facts.os == "macOS" && facts.facts.platform == "aarch64-darwin";
    assert
      lib.hasInfix "# macOS workflow" facts.context && !lib.hasInfix "# NixOS workflow" facts.context;
    assert !darwin.config.services.tailscale.enable;
    assert darwin.config.homebrew.masApps.Tailscale == 1475387142;
    assert !lib.any (c: c.name == "tailscale-app") darwin.config.homebrew.casks;
    assert lib.any (c: c.name == "stablyai/orca/orca") darwin.config.homebrew.casks;
    assert lib.all (name: lib.any (c: c.name == name) darwin.config.homebrew.casks) [
      "kitty"
      "hammerspoon"
      "karabiner-elements"
      "aerospace"
    ];
    assert lib.getName home.config.fleet.interaction.backend == "fleet-ui-backend";
    assert builtins.elem "${darwin.config.homebrew.prefix}/bin" (
      lib.splitString ":" darwin.config.environment.systemPath
    );
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
            pkgs.lsof
            pkgs.bash
            pkgs.jq
            pkgs.coreutils
            pkgs.syncthing
            pkgs.libxml2
            pkgs.shellcheck
          ];
        }
        ''
          export PYTHONDONTWRITEBYTECODE=1
          python ${../scripts/tests/check-workspace-context.py} ${../scripts/workspace-context.py}
          python ${../scripts/tests/check-portable-workspace.py} ${../scripts}
          python ${../scripts/tests/check-workspace-receive.py} ${../scripts}
          bash ${../scripts/tests/check-nix-config.sh} ${../scripts/nix-config.sh}
          shellcheck ${../scripts/macos-readiness.sh} ${../scripts/tests/check-macos-readiness.sh}
          bash ${../scripts/tests/check-macos-readiness.sh} ${../scripts/macos-readiness.sh}
          # Validate the actual package's CLI and initial folder policy without
          # running a daemon or publishing generated keys/configuration.
          umask 077
          export STHOMEDIR="$TMPDIR/syncthing-bootstrap"
          syncthing serve ${lib.escapeShellArgs home.config.services.syncthing.extraOptions} --help >/dev/null
          syncthing generate --no-port-probing
          test "$(xmllint --xpath 'count(configuration/folder)' "$STHOMEDIR/config.xml")" = 0
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
