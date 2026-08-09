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
  };

  outputs = { nixpkgs, home-manager, catppuccin, ... }@inputs:
  let
    lib = nixpkgs.lib;
    system = "x86_64-linux";
    username = "anthony";
    specialArgs = { inherit inputs username; };
    pkgsFor = import nixpkgs {
      localSystem = system;
      config.allowUnfree = true;
    };
    workstations = {
      victus = {
        systemModule = ./hosts/victus;
        homeModules = [ ./hosts/victus/home.nix ];
        features = {
          graphics = "nvidia-prime";
          creativeNvidia = true;
          monitorProfile = "dynamic";
        };
      };
      desktop = {
        systemModule = ./hosts/desktop;
        homeModules = [ ./hosts/desktop/home.nix ];
        features = {
          graphics = "nvidia";
          creativeNvidia = true;
          monitorProfile = "desktop-3";
        };
      };
      thinkpad = {
        systemModule = ./hosts/thinkpad;
        homeModules = [ ./hosts/thinkpad/home.nix ];
        features = {
          graphics = "intel";
          creativeNvidia = false;
          monitorProfile = "dynamic";
        };
      };
    };
    mkHost = host:
      lib.nixosSystem {
        inherit system specialArgs;
        modules = [
          host.systemModule
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.users.${username}.imports = [ ./home.nix ] ++ host.homeModules;
            home-manager.extraSpecialArgs = {
              inherit inputs username;
              hostFeatures = host.features;
            };
            home-manager.sharedModules = [ catppuccin.homeModules.catppuccin ];
          }
        ];
      };
    mkHome = host:
      home-manager.lib.homeManagerConfiguration {
        pkgs = pkgsFor;
        extraSpecialArgs = {
          inherit inputs username;
          hostFeatures = host.features;
        };
        modules = [ ./home.nix catppuccin.homeModules.catppuccin ] ++ host.homeModules;
      };
  in {
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

    homeConfigurations = lib.mapAttrs'
      (name: host: lib.nameValuePair "${username}@${name}" (mkHome host))
      workstations;
  };
}
