{
  description = "Toño's Master Multi-Host NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin.url = "github:catppuccin/nix";
  };

  outputs = { nixpkgs, home-manager, catppuccin, ... }@inputs:
  let
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
  in {
    nixosConfigurations = {
      victus = nixpkgs.lib.nixosSystem {
        inherit system specialArgs;
        modules = [
          ./hosts/victus/default.nix
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.anthony = import ./home.nix;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.sharedModules = [ catppuccin.homeModules.catppuccin ];
          }
        ];
      };
    };
  };
}
