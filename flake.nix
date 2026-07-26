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
    mkHost = hostPath: extraHomeModules:
      lib.nixosSystem {
        inherit system specialArgs;
        modules = [
          hostPath
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.users.${username}.imports = [ ./home.nix ] ++ extraHomeModules;
            home-manager.extraSpecialArgs = { inherit inputs username; };
            home-manager.sharedModules = [ catppuccin.homeModules.catppuccin ];
          }
        ];
      };
    hostIfReady = name: hostPath: extraHomeModules:
      lib.optionalAttrs (builtins.pathExists "${toString hostPath}/hardware-configuration.nix") {
        ${name} = mkHost hostPath extraHomeModules;
      };
  in {
    nixosConfigurations =
      {
        # victus y desktop traen modules/home/creative-suite.nix
        # (davinci-resolve, blender, kdenlive, etc.): ambas tienen GPU NVIDIA
        # dedicada (victus: RTX 4050 híbrida + PRIME offload; desktop: RTX
        # 3060 Ti única, sin iGPU). thinkpad se queda con el home.nix base —
        # ver CLAUDE.md, "3D/video creation stack".
        victus = mkHost ./hosts/victus [ ./modules/home/creative-suite.nix ];

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
      }
      // hostIfReady "thinkpad" ./hosts/thinkpad []
      // hostIfReady "desktop" ./hosts/desktop [
        ./modules/home/creative-suite.nix
        ./modules/home/monitors-desktop.nix # layout fijo de 3 monitores, ver ese archivo
      ];

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
