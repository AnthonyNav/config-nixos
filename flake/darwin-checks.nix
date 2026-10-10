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
    assert !home.config.fleet.development.legacyJupyterLibraries;
    assert facts.facts.os == "macOS" && facts.facts.platform == "aarch64-darwin";
    assert
      lib.hasInfix "# macOS workflow" facts.context && !lib.hasInfix "# NixOS workflow" facts.context;
    assert !darwin.config.services.tailscale.enable;
    assert darwin.config.homebrew.masApps.Tailscale == 1475387142;
    assert !lib.any (c: c.name == "tailscale-app") darwin.config.homebrew.casks;
    assert lib.any (c: c.name == "stablyai/orca/orca") darwin.config.homebrew.casks;
    assert !lib.any (c: c.name == "pritunl") darwin.config.homebrew.casks;
    assert lib.any (
      c: c.name == "pritunl"
    ) outputs.darwinConfigurations.MacBook-Pro-de-Antonio.config.homebrew.casks;
    assert lib.all (name: lib.any (c: c.name == name) darwin.config.homebrew.casks) [
      "kitty"
      "karabiner-elements"
      "dbgate"
    ];
    assert
      !lib.any (
        c:
        builtins.elem c.name [
          "hammerspoon"
          "aerospace"
        ]
      ) darwin.config.homebrew.casks;
    assert !lib.any (t: t.name == "nikitabobko/tap") darwin.config.homebrew.taps;
    assert !(home.config.home.file ? ".hammerspoon/init.lua");
    assert !(home.config.home.file ? ".hammerspoon/fleet.lua");
    assert !(home.config.home.file ? ".aerospace.toml");
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
    native-controls =
      pkgs.runCommand "darwin-native-controls-check"
        {
          nativeBuildInputs = [
            pkgs.bash
            pkgs.coreutils
            pkgs.shellcheck
          ];
        }
        ''
          shellcheck ${../modules/home/darwin/fleet-ui-native.sh}
          backend=${home.config.fleet.interaction.backend}/bin/fleet-ui-backend
          for action in menu capture-menu record-menu media-menu move-mode resize-mode resize focus move workspace move-workspace fullscreen toggle-floating resize-step mode-exit edit lock; do
            status=0
            "$backend" "$action" >output 2>error || status=$?
            test "$status" = 64
            test ! -s output
            grep -q 'retired on macOS' error
          done
          "$backend" --help >help
          grep -q 'native keyboard and window controls' help
          ! grep -Eq 'focus|workspace|move-mode|resize-mode|edit|menu' help
          "$backend" shortcuts >guide
          grep -q 'macOS: controles nativos' guide
          ! grep -q 'Cmd+Option+Enter' guide
          status=0
          "$backend" shortcuts --hold extra >/dev/null 2>&1 || status=$?
          test "$status" = 2
          mkdir mock
          cat >mock/fleet-media <<'EOF'
          #!/usr/bin/env bash
          printf '%s\n' "$@" >"$FLEET_NATIVE_MEDIA_CALL"
          EOF
          chmod +x mock/fleet-media
          export PATH="$PWD/mock:$PATH"
          export FLEET_NATIVE_MEDIA_CALL="$PWD/media-call"
          "$backend" screenshot area --clipboard
          printf '%s\n' --platform darwin screenshot area --clipboard >expected
          cmp expected media-call
          "$backend" record status
          printf '%s\n' --platform darwin record status >expected
          cmp expected media-call
          touch "$out"
        '';
    fleet-interaction = import ./fleet-interaction-check.nix {
      inherit pkgs;
      source = ../.;
    };
    workspace-sync =
      pkgs.runCommand "darwin-workspace-sync-check"
        {
          nativeBuildInputs = [
            pkgs.python3
            pkgs.syncthing
          ];
        }
        ''
          export PYTHONDONTWRITEBYTECODE=1
          python ${../scripts/tests/check-workspace-sync.py} ${../scripts/syncthing-ignores.py} ${pkgs.writeText "workspace-sync-policy.json" (builtins.toJSON (import ../inventory/syncthing.nix))} ${pkgs.syncthing}/bin/syncthing
          touch "$out"
        '';
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
          ];
        }
        ''
          export PYTHONDONTWRITEBYTECODE=1
          python ${../scripts/tests/check-workspace-context.py} ${../scripts/workspace-context.py}
          python ${../scripts/tests/check-portable-workspace.py} ${../scripts}
          python ${../scripts/tests/check-workspace-receive.py} ${../scripts}
          bash ${../scripts/tests/check-nix-config.sh} ${../scripts/nix-config.sh}
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
