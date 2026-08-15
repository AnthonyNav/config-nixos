{
  description = "Toño's Master Multi-Host NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

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
      treefmtEval = treefmt-nix.lib.evalModule pkgsFor ./treefmt.nix;
      opencodePackages = import ./modules/home/opencode-packages.nix {
        inherit lib;
        pkgs = pkgsFor;
      };
      desktopStyles = {
        caelestia = {
          systemModule = ./desktops/caelestia/system.nix;
          homeModule = ./desktops/caelestia/home.nix;
        };
      };
      workstations = {
        victus = {
          systemModule = ./hosts/victus;
          homeModules = [ ./hosts/victus/home.nix ];
          desktopStyle = "caelestia";
          features = {
            graphics = "nvidia-prime";
            creativeNvidia = true;
            monitorProfile = "dynamic";
          };
        };
        desktop = {
          systemModule = ./hosts/desktop;
          homeModules = [ ./hosts/desktop/home.nix ];
          desktopStyle = "caelestia";
          features = {
            graphics = "nvidia";
            creativeNvidia = true;
            monitorProfile = "desktop-3";
          };
        };
        thinkpad = {
          systemModule = ./hosts/thinkpad;
          homeModules = [ ./hosts/thinkpad/home.nix ];
          desktopStyle = "caelestia";
          features = {
            graphics = "intel";
            creativeNvidia = false;
            monitorProfile = "dynamic";
          };
        };
      };
      workstationNames = builtins.attrNames workstations;
      nixConfigPackages = import ./modules/home/nix-config-packages.nix {
        inherit lib username workstationNames;
        pkgs = pkgsFor;
      };
      mkHost =
        host:
        let
          style =
            desktopStyles.${host.desktopStyle} or (throw "Unknown desktop style '${host.desktopStyle}'.");
          hostFeatures = host.features // {
            desktopStyle = host.desktopStyle;
          };
        in
        lib.nixosSystem {
          inherit system specialArgs;
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
        host:
        let
          style =
            desktopStyles.${host.desktopStyle} or (throw "Unknown desktop style '${host.desktopStyle}'.");
          hostFeatures = host.features // {
            desktopStyle = host.desktopStyle;
          };
        in
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor;
          extraSpecialArgs = {
            inherit
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
      lib.workstationNames = workstationNames;

      nixosConfigurations = (lib.mapAttrs (_: mkHost) workstations) // {
        # ISO instaladora personalizada, no un host real: SSH ya autorizado +
        # este repo pre-cargado en /etc/nixos-config (ver iso/installer.nix),
        # para instalar hosts nuevos completamente por SSH desde otra
        # máquina. Build: nix build .#nixosConfigurations.installer.config.system.build.isoImage
        installer = lib.nixosSystem {
          inherit system specialArgs;
          modules = [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            ./iso/installer.nix
          ];
        };
      };

      homeConfigurations = lib.mapAttrs' (
        name: host: lib.nameValuePair "${username}@${name}" (mkHome host)
      ) workstations;

      formatter.${system} = treefmtEval.config.build.wrapper;
      packages.${system}.nix-config = nixConfigPackages.nixConfig;
      apps.${system}.nix-config = {
        type = "app";
        program = lib.getExe nixConfigPackages.nixConfig;
        meta.description = "Validate, build, and deploy this NixOS configuration";
      };
      checks.${system} = {
        formatting = treefmtEval.config.build.check self;
        nix-config =
          pkgsFor.runCommand "nix-config-check"
            {
              nativeBuildInputs = [
                pkgsFor.bash
                pkgsFor.git
                pkgsFor.shellcheck
                nixConfigPackages.nixConfig
              ];
            }
            ''
              shellcheck ${./scripts/nix-config.sh} ${./scripts/tests/check-nix-config.sh}
              bash ${./scripts/tests/check-nix-config.sh} ${./scripts/nix-config.sh}
              nix-config --help >/dev/null
              touch "$out"
            '';
        opencode-workflow =
          pkgsFor.runCommand "opencode-workflow-check"
            {
              nativeBuildInputs = [
                pkgsFor.git
                pkgsFor.jq
                pkgsFor.opencode
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
          nixfmt
          statix
          deadnix
          shellcheck
          nodejs_22
          jq
        ];
      };
    };
}
