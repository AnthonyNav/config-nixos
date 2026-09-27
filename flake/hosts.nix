{
  inputs,
  username,
  fleet,
}:
let
  inherit (inputs.nixpkgs) lib;
  desktopStyles.caelestia = {
    systemModule = ../desktops/caelestia/system.nix;
    homeModule = ../desktops/caelestia/home.nix;
  };
  styleFor =
    host:
    if host.desktopStyle == null then
      null
    else
      desktopStyles.${host.desktopStyle} or (throw "Unknown desktop style '${host.desktopStyle}'.");
  pkgsFor =
    system:
    import inputs.nixpkgs {
      localSystem = system;
      config.allowUnfree = true;
    };
  argsFor = name: host: {
    inherit inputs username;
    fleetInventory = fleet.inventory;
    fleetNames = fleet.hostNames;
    inherit (fleet) workstationNames homeHostNames inputSharingHostNames;
    hostFeatures = host.features // {
      hostName = name;
      inherit (host)
        role
        kind
        system
        desktopStyle
        connectivity
        capabilities
        ;
    };
  };
  homeArgsFor =
    name: host:
    let
      pkgs = pkgsFor host.system;
    in
    (argsFor name host)
    // {
      aiToolsPackages = inputs.llm-agents.packages.${host.system};
      herdrPackage = inputs.herdr.packages.${host.system}.default;
      kiroPackages = import ../packages/kiro.nix { inherit pkgs; };
      dbgatePackage = pkgs.callPackage ../packages/dbgate.nix { };
      dbeaverPackage = import ../packages/dbeaver.nix { inherit pkgs; };
    };
  homeModulesFor =
    host:
    let
      style = styleFor host;
    in
    lib.optional (host.kind == "workstation") ../home.nix
    ++ lib.optional (style != null) style.homeModule
    ++ [ inputs.catppuccin.homeModules.catppuccin ]
    ++ host.homeModules;
  mkHost =
    name: host:
    let
      style = styleFor host;
    in
    inputs.nixpkgs.lib.nixosSystem {
      system = host.system;
      specialArgs = argsFor name host;
      modules = [
        host.systemModule
      ]
      ++ lib.optional (style != null) style.systemModule
      ++ lib.optionals (host.homeModules != null) [
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";
          home-manager.users.${username}.imports = homeModulesFor host;
          home-manager.extraSpecialArgs = homeArgsFor name host;
        }
      ]
      ++ lib.optional (host.homeModules == null) (
        { pkgs, ... }: {
          environment.systemPackages = builtins.attrValues (
            import ../modules/home/nix-config-packages.nix {
              inherit lib pkgs username;
              fleetNames = fleet.hostNames;
              inherit (fleet) homeHostNames;
            }
          );
        }
      );
    };
  mkHome =
    name: host:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = pkgsFor host.system;
      extraSpecialArgs = homeArgsFor name host;
      modules = homeModulesFor host;
    };
in
{
  inherit mkHost;
  nixosConfigurations = lib.mapAttrs mkHost fleet.hosts;
  homeConfigurations = lib.mapAttrs' (
    name: host: lib.nameValuePair "${username}@${name}" (mkHome name host)
  ) (lib.getAttrs fleet.homeHostNames fleet.hosts);
}
