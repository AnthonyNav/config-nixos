{
  description = "Toño's Master Multi-Host NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin.url = "github:catppuccin/nix";

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
      inherit system;
      config.allowUnfree = true;
    };
    mkHost = hostPath:
      lib.nixosSystem {
        inherit system specialArgs;
        modules = [
          hostPath
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.users.${username} = import ./home.nix;
            home-manager.extraSpecialArgs = { inherit inputs username; };
            home-manager.sharedModules = [ catppuccin.homeModules.catppuccin ];
          }
        ];
      };
    hostIfReady = name: hostPath:
      lib.optionalAttrs (builtins.pathExists "${toString hostPath}/hardware-configuration.nix") {
        ${name} = mkHost hostPath;
      };
  in {
    nixosConfigurations =
      {
        victus = mkHost ./hosts/victus;
      }
      // hostIfReady "thinkpad" ./hosts/thinkpad
      // hostIfReady "desktop" ./hosts/desktop;

    homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
      pkgs = pkgsFor;
      extraSpecialArgs = { inherit inputs username; };
      modules = [
        ./home.nix
        catppuccin.homeModules.catppuccin
      ];
    };
  };
}
