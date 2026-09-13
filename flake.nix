{
  description = "Toño's Master Multi-Host NixOS Configuration";

  nixConfig = {
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    llm-agents.url = "github:numtide/llm-agents.nix";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    kiro-gateway = {
      url = "github:AnthonyNav/kiro-gateway/5562ad43b6bd4ce05a663130c574402cef0e2f32";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      catppuccin,
      treefmt-nix,
      ...
    }@inputs:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      username = "anthony";
      specialArgs = { inherit inputs username; };
      pkgsFor = import nixpkgs {
        localSystem = system;
        config.allowUnfree = true;
      };
      aiToolsPackages = inputs.llm-agents.packages.${system};
      aiToolVersions = {
        claudeCode = aiToolsPackages.claude-code.version;
        codex = aiToolsPackages.codex.version;
        opencode = aiToolsPackages.opencode.version;
        rtk = aiToolsPackages.rtk.version;
      };
      treefmtEval = treefmt-nix.lib.evalModule pkgsFor ./treefmt.nix;
      opencodePackages = import ./modules/home/opencode-packages.nix {
        inherit lib;
        opencodePackage = aiToolsPackages.opencode;
        pkgs = pkgsFor;
      };
      desktopStyles = {
        caelestia = {
          systemModule = ./desktops/caelestia/system.nix;
          homeModule = ./desktops/caelestia/home.nix;
        };
      };
      workstations = import ./inventory/workstations.nix;
      workstationNames = builtins.attrNames workstations;
      fleetInventory = lib.mapAttrs (name: host: {
        inherit name;
        inherit (host)
          role
          desktopStyle
          connectivity
          features
          ;
      }) workstations;
      fleetEndpoints = import ./inventory/endpoints.nix;
      tailscalePolicyConfig = import ./inventory/tailscale.nix { inherit username; };
      tailnetPolicy = tailscalePolicyConfig.tailnetPolicy;
      tailnetPolicyFile = pkgsFor.writeText "tailscale-policy.json" (builtins.toJSON tailnetPolicy);
      tailscalePolicyPrinter = pkgsFor.writeShellApplication {
        name = "tailscale-policy";
        text = ''
          ${pkgsFor.jq}/bin/jq . ${tailnetPolicyFile}
        '';
      };
      nixConfigPackages = import ./modules/home/nix-config-packages.nix {
        inherit lib username workstationNames;
        pkgs = pkgsFor;
      };
      mkHost =
        name: host:
        let
          style =
            desktopStyles.${host.desktopStyle} or (throw "Unknown desktop style '${host.desktopStyle}'.");
          hostFeatures = host.features // {
            hostName = name;
            role = host.role;
            connectivity = host.connectivity;
            desktopStyle = host.desktopStyle;
          };
        in
        lib.nixosSystem {
          inherit system;
          specialArgs = specialArgs // {
            inherit fleetInventory hostFeatures;
          };
          modules = [
            style.systemModule
            host.systemModule
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "hm-backup";
              home-manager.users.${username}.imports = [
                ./home.nix
                style.homeModule
              ]
              ++ host.homeModules;
              home-manager.extraSpecialArgs = {
                inherit
                  aiToolsPackages
                  fleetInventory
                  inputs
                  username
                  workstationNames
                  ;
                inherit hostFeatures;
              };
              home-manager.sharedModules = [ catppuccin.homeModules.catppuccin ];
            }
          ];
        };
      mkHome =
        name: host:
        let
          style =
            desktopStyles.${host.desktopStyle} or (throw "Unknown desktop style '${host.desktopStyle}'.");
          hostFeatures = host.features // {
            hostName = name;
            role = host.role;
            connectivity = host.connectivity;
            desktopStyle = host.desktopStyle;
          };
        in
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor;
          extraSpecialArgs = {
            inherit
              aiToolsPackages
              fleetInventory
              inputs
              username
              workstationNames
              ;
            inherit hostFeatures;
          };
          modules = [
            ./home.nix
            style.homeModule
            catppuccin.homeModules.catppuccin
          ]
          ++ host.homeModules;
        };
    in
    {
      lib = {
        inherit
          aiToolVersions
          fleetEndpoints
          fleetInventory
          tailnetPolicy
          workstationNames
          ;
      };

      nixosConfigurations = (lib.mapAttrs mkHost workstations) // {
        installer = lib.nixosSystem {
          inherit system specialArgs;
          modules = [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            ./iso/installer.nix
          ];
        };
      };

      homeConfigurations = lib.mapAttrs' (
        name: host: lib.nameValuePair "${username}@${name}" (mkHome name host)
      ) workstations;

      formatter.${system} = treefmtEval.config.build.wrapper;
      packages.${system} = {
        nix-config = nixConfigPackages.nixConfig;
        gitleaks = pkgsFor.gitleaks;
        tailscale-policy = tailscalePolicyPrinter;
      };
      apps.${system} = {
        nix-config = {
          type = "app";
          program = lib.getExe nixConfigPackages.nixConfig;
          meta.description = "Validate, build, and deploy this NixOS configuration";
        };
        tailscale-policy = {
          type = "app";
          program = lib.getExe tailscalePolicyPrinter;
          meta.description = "Render the declared Tailscale tailnet policy";
        };
      };
      checks.${system} = {
        development-path = pkgsFor.runCommand "development-path-check" { } ''
          mkdir -p "$TMPDIR"/{managed,project,home/.local/bin,home/.local/share/pnpm,home/.npm-global/bin}
          touch "$TMPDIR/managed/codex" "$TMPDIR/project/codex" \
            "$TMPDIR/home/.npm-global/bin/codex" "$TMPDIR/home/.local/bin/local-only"
          chmod +x "$TMPDIR/managed/codex" "$TMPDIR/project/codex" \
            "$TMPDIR/home/.npm-global/bin/codex" "$TMPDIR/home/.local/bin/local-only"
          HOME="$TMPDIR/home" TEST_ROOT="$TMPDIR" ${pkgsFor.zsh}/bin/zsh -f ${pkgsFor.writeText "development-path-test.zsh" ''
            set -eu
            path=("$HOME/.npm-global/bin" "$HOME/.local/bin" "$TEST_ROOT/project" "$TEST_ROOT/managed")
            source ${./scripts/development-path.zsh}
            [[ "$(whence -p codex)" == "$TEST_ROOT/project/codex" ]]
            path=("''${(@)path:#$TEST_ROOT/project}")
            source ${./scripts/development-path.zsh}
            [[ "$(whence -p codex)" == "$TEST_ROOT/managed/codex" ]]
            [[ "$(whence -p local-only)" == "$HOME/.local/bin/local-only" ]]
            previous_path=$PATH
            source ${./scripts/development-path.zsh}
            [[ "$PATH" == "$previous_path" ]]
          ''}
          touch "$out"
        '';
        resource-policy =
          let
            configs = lib.mapAttrs (_: host: host.config) (
              lib.getAttrs workstationNames self.nixosConfigurations
            );
            thinkpad = configs.thinkpad;
            victus = configs.victus;
            thinkpadFallbackSwap = builtins.filter (
              swap: swap.device == "/var/lib/nixos-memory-swapfile"
            ) thinkpad.swapDevices;
            victusFallbackSwap = builtins.filter (
              swap: swap.device == "/var/lib/nixos-victus-memory-swapfile"
            ) victus.swapDevices;
          in
          assert lib.all (c: c.nix.settings.cores > 0 && c.nix.settings."max-jobs" > 0) (
            builtins.attrValues configs
          );
          assert thinkpad.nix.settings."max-jobs" <= configs.desktop.nix.settings."max-jobs";
          assert configs.desktop.nix.settings."max-jobs" == 1;
          assert configs.desktop.nix.settings.cores == 1;
          assert builtins.length thinkpadFallbackSwap == 1;
          assert (builtins.head thinkpadFallbackSwap).randomEncryption.enable;
          assert (builtins.head thinkpadFallbackSwap).priority < thinkpad.zramSwap.priority;
          assert builtins.length victusFallbackSwap == 1;
          assert (builtins.head victusFallbackSwap).randomEncryption.enable;
          assert (builtins.head victusFallbackSwap).priority < victus.zramSwap.priority;
          assert !thinkpad.systemd.sleep.settings.Sleep.AllowHibernation;
          assert !thinkpad.systemd.sleep.settings.Sleep.AllowHybridSleep;
          assert !thinkpad.systemd.sleep.settings.Sleep.AllowSuspendThenHibernate;
          assert !victus.systemd.sleep.settings.Sleep.AllowHibernation;
          assert !victus.systemd.sleep.settings.Sleep.AllowHybridSleep;
          assert !victus.systemd.sleep.settings.Sleep.AllowSuspendThenHibernate;
          assert !(builtins.elem "multi-user.target" thinkpad.systemd.services.docker.wantedBy);
          assert builtins.elem "sockets.target" thinkpad.systemd.sockets.docker.wantedBy;
          assert !(builtins.elem "multi-user.target" victus.systemd.services.docker.wantedBy);
          assert builtins.elem "sockets.target" victus.systemd.sockets.docker.wantedBy;
          assert thinkpad.virtualisation.docker.enable && !thinkpad.virtualisation.docker.enableOnBoot;
          assert victus.virtualisation.docker.enable && !victus.virtualisation.docker.enableOnBoot;
          assert
            configs.desktop.virtualisation.docker.enable && configs.desktop.virtualisation.docker.enableOnBoot;
          assert victus.hardware.nvidia-container-toolkit.enable;
          assert configs.desktop.services.k3s.enable;
          pkgsFor.runCommand "resource-policy-check" { } ''
            touch "$out"
          '';
        ai-tools =
          pkgsFor.runCommand "ai-tools-check"
            {
              nativeBuildInputs = [
                aiToolsPackages.claude-code
                aiToolsPackages.codex
                aiToolsPackages.opencode
                aiToolsPackages.rtk
              ];
            }
            ''
              export HOME="$TMPDIR/home"
              export XDG_CACHE_HOME="$TMPDIR/cache"
              export XDG_CONFIG_HOME="$TMPDIR/config"
              export XDG_DATA_HOME="$TMPDIR/data"
              export XDG_STATE_HOME="$TMPDIR/state"
              mkdir -p "$HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"

              claude --version | grep -F ${lib.escapeShellArg aiToolVersions.claudeCode}
              codex --version | grep -F ${lib.escapeShellArg aiToolVersions.codex}
              opencode --version | grep -F ${lib.escapeShellArg aiToolVersions.opencode}
              rtk --version | grep -F ${lib.escapeShellArg aiToolVersions.rtk}
              touch "$out"
            '';
        formatting = treefmtEval.config.build.check self;
        ci-workflows =
          pkgsFor.runCommand "ci-workflows-check"
            {
              nativeBuildInputs = [ pkgsFor.actionlint ];
            }
            ''
              actionlint \
                ${./.github/workflows/flake-check.yml} \
                ${./.github/workflows/full-build.yml}
              touch "$out"
            '';
        network-endpoints =
          let
            allEndpoints = fleetEndpoints.tailnet ++ fleetEndpoints.public;
            endpointHosts = lib.concatMap (endpoint: endpoint.hosts) allEndpoints;
            endpointBindings = lib.concatMap (
              endpoint: map (host: "${host}:${endpoint.protocol}:${toString endpoint.port}") endpoint.hosts
            ) allEndpoints;
            tailnetGrantBindings = map (
              endpoint: "${endpoint.protocol}:${toString endpoint.port}"
            ) fleetEndpoints.tailnet;
            expectedInputPeers =
              host: lib.sort builtins.lessThan (builtins.filter (name: name != host) workstationNames);
            declaredInputPeers =
              host:
              lib.sort builtins.lessThan (map (peer: peer.host) workstations.${host}.features.inputSharing.peers);
            expectedRemoteWorkspaceHosts = builtins.filter (
              name: workstations.${name}.features.remoteWorkspace.enable
            ) workstationNames;
            validPort = endpoint: endpoint.port > 0 && endpoint.port <= 65535;
          in
          assert lib.all (host: builtins.elem host workstationNames) endpointHosts;
          assert lib.all validPort allEndpoints;
          assert builtins.length endpointBindings == builtins.length (lib.unique endpointBindings);
          assert builtins.length tailnetGrantBindings == builtins.length (lib.unique tailnetGrantBindings);
          assert lib.all (host: declaredInputPeers host == expectedInputPeers host) workstationNames;
          assert builtins.attrNames fleetEndpoints.remoteWorkspace.hosts == expectedRemoteWorkspaceHosts;
          assert
            fleetEndpoints.remoteWorkspace.hosts.desktop.httpsPort
            != fleetEndpoints.desktop.woodpeckerHttp.httpsPort;
          pkgsFor.runCommand "network-endpoints-check" { } ''
            touch "$out"
          '';
        identity-policy =
          let
            homeConfig = self.homeConfigurations."${username}@thinkpad".config;
            gitSettings = homeConfig.programs.git.settings;
            sshSettings = homeConfig.programs.ssh.settings;
            identityPolicy = import ./inventory/identities.nix;
          in
          assert identityPolicy.default == "work";
          assert gitSettings.user.useConfigOnly;
          assert gitSettings.user.email == identityPolicy.identities.work.git.email;
          assert
            gitSettings.url."git@github.com:".insteadOf == [
              "https://github.com/"
              "ssh://git@github.com/"
            ];
          assert sshSettings."github.com".data.IdentityFile == "/home/${username}/.ssh/id_work";
          assert sshSettings."github.com-personal".data.IdentityFile == "/home/${username}/.ssh/id_personal";
          assert sshSettings."github.com-work".data.IdentityFile == "/home/${username}/.ssh/id_work";
          assert sshSettings."github.com-kigo".data.IdentityFile == "/home/${username}/.ssh/id_work";
          assert builtins.elem "projects/" identityPolicy.identities.personal.roots;
          assert builtins.elem "nixos-config/" identityPolicy.identities.personal.roots;
          assert identityPolicy.identities.work.aws.profile == "work-readonly";
          assert identityPolicy.identities.personal.aws.profile == "personal-readonly";
          pkgsFor.runCommand "identity-policy-check" { } ''
            touch "$out"
          '';
        tailscale-policy =
          let
            systemConfig = self.nixosConfigurations.thinkpad.config;
            homeConfig = self.homeConfigurations."${username}@thinkpad".config;
            tailscaleConfig = systemConfig.services.tailscale;
            tailscaleFirewall = systemConfig.networking.firewall.interfaces.tailscale0;
            fleetSshSettings = homeConfig.programs.ssh.settings;
            grant = builtins.head tailnetPolicy.grants;
            sshRule = builtins.head tailnetPolicy.ssh;
            expectedGrantIps = builtins.map (
              endpoint: "${endpoint.protocol}:${toString endpoint.port}"
            ) fleetEndpoints.tailnet;
            expectedProxyCommand = "${lib.getExe pkgsFor.tailscale} nc %h %p";
          in
          assert tailscaleConfig.enable;
          assert tailscalePolicyConfig.node.allowIncoming;
          assert
            tailscaleConfig.extraSetFlags == [
              "--hostname=thinkpad"
              "--shields-up=false"
              "--ssh"
            ];
          assert systemConfig.services.openssh.enable;
          assert builtins.elem fleetEndpoints.ports.ssh tailscaleFirewall.allowedTCPPorts;
          assert grant.src == [ "autogroup:member" ];
          assert grant.dst == [ "autogroup:self" ];
          assert grant.ip == expectedGrantIps;
          assert !(builtins.elem "*" grant.ip);
          assert sshRule.action == "check";
          assert sshRule.src == [ "autogroup:member" ];
          assert sshRule.dst == [ "autogroup:self" ];
          assert sshRule.users == [ username ];
          assert sshRule.checkPeriod == "12h";
          assert fleetSshSettings.thinkpad.data.User == username;
          assert fleetSshSettings.desktop.data.User == username;
          assert fleetSshSettings.victus.data.User == username;
          assert fleetSshSettings.thinkpad.data.ProxyCommand == expectedProxyCommand;
          assert fleetSshSettings.desktop.data.ProxyCommand == expectedProxyCommand;
          assert fleetSshSettings.victus.data.ProxyCommand == expectedProxyCommand;
          pkgsFor.runCommand "tailscale-policy-check" { } ''
            ${lib.getExe tailscalePolicyPrinter} >/dev/null
            touch "$out"
          '';
        syncthing-policy =
          let
            systemConfig = self.nixosConfigurations.thinkpad.config;
            syncthingConfig = systemConfig.services.syncthing;
            tailscaleFirewall = systemConfig.networking.firewall.interfaces.tailscale0;
            syncthingPolicy = import ./inventory/syncthing.nix;
          in
          assert syncthingConfig.enable;
          assert !syncthingConfig.overrideDevices;
          assert !syncthingConfig.overrideFolders;
          assert
            syncthingConfig.settings.options.listenAddresses == [
              "tcp://0.0.0.0:${toString fleetEndpoints.ports.syncthing}"
            ];
          assert !syncthingConfig.settings.options.globalAnnounceEnabled;
          assert !syncthingConfig.settings.options.localAnnounceEnabled;
          assert !syncthingConfig.settings.options.relaysEnabled;
          assert !syncthingConfig.settings.options.natEnabled;
          assert builtins.elem fleetEndpoints.ports.syncthing tailscaleFirewall.allowedTCPPorts;
          assert !(builtins.elem fleetEndpoints.ports.syncthing (tailscaleFirewall.allowedUDPPorts or [ ]));
          assert !(builtins.elem 21027 (tailscaleFirewall.allowedUDPPorts or [ ]));
          assert syncthingPolicy.folders.shared.id == "fleet-shared";
          assert syncthingPolicy.folders.shared.relativePath == "Sync/Fleet";
          pkgsFor.runCommand "syncthing-policy-check" { } ''
            touch "$out"
          '';
        remote-workspace-policy =
          let
            systemConfig = self.nixosConfigurations.desktop.config;
            remotePolicy = import ./inventory/remote-workspace.nix;
            remoteEndpoint = remotePolicy.hosts.desktop;
            globalTcpPorts = systemConfig.networking.firewall.allowedTCPPorts or [ ];
            tailscaleTcpPorts = systemConfig.networking.firewall.interfaces.tailscale0.allowedTCPPorts or [ ];
          in
          assert workstations.desktop.features.remoteWorkspace.enable;
          assert !workstations.thinkpad.features.remoteWorkspace.enable;
          assert !workstations.victus.features.remoteWorkspace.enable;
          assert builtins.attrNames remotePolicy.hosts == [ "desktop" ];
          assert builtins.elem remoteEndpoint.httpsPort tailscaleTcpPorts;
          assert !(builtins.elem remotePolicy.backend.port globalTcpPorts);
          assert !(builtins.elem remotePolicy.backend.port tailscaleTcpPorts);
          assert remotePolicy.backend.hostname == "127.0.0.1";
          assert aiToolsPackages ? codex;
          pkgsFor.runCommand "remote-workspace-policy-check" { } ''
            touch "$out"
          '';
        nix-config =
          pkgsFor.runCommand "nix-config-check"
            {
              nativeBuildInputs = [
                pkgsFor.bash
                pkgsFor.coreutils
                pkgsFor.git
                pkgsFor.gnused
                pkgsFor.jq
                pkgsFor.shellcheck
                pkgsFor.util-linux
                nixConfigPackages.nixConfig
              ];
            }
            ''
              shellcheck \
                ${./scripts/nix-config.sh} \
                ${./scripts/tests/check-nix-config.sh} \
                ${./scripts/tests/check-input-share.sh} \
                ${./scripts/input-share-reconcile.sh} \
                ${./scripts/syncthing-fleet-reconcile.sh} \
                ${./scripts/lab.sh} \
                ${./opencode/tests/check-workflow.sh}
              bash ${./scripts/tests/check-nix-config.sh} ${./scripts/nix-config.sh}
              bash ${./scripts/tests/check-input-share.sh} ${./scripts/input-share-reconcile.sh}
              nix-config --help >/dev/null
              touch "$out"
            '';
        opencode-workflow =
          pkgsFor.runCommand "opencode-workflow-check"
            {
              nativeBuildInputs = [
                pkgsFor.git
                pkgsFor.jq
                aiToolsPackages.opencode
              ];
            }
            ''
              ${pkgsFor.bash}/bin/bash ${./opencode/tests/check-workflow.sh} \
                ${lib.getExe opencodePackages.workflow} \
                ${lib.getExe opencodePackages.managedTreeState} \
                ${lib.getExe opencodePackages.managedPrepareNewFiles} \
                ${lib.getExe opencodePackages.managedNixFormatter}
              touch "$out"
            '';
      };
      devShells.${system}.default = pkgsFor.mkShell {
        packages = with pkgsFor; [
          treefmtEval.config.build.wrapper
          actionlint
          nixfmt
          statix
          deadnix
          shellcheck
          gitleaks
          nodejs_22
          jq
        ];
      };
    };
}
