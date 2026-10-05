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
    host: desktopStyles.${host.desktopStyle} or (throw "Unknown desktop style '${host.desktopStyle}'.");
  pkgsFor =
    system:
    import inputs.nixpkgs {
      localSystem = system;
      config.allowUnfree = true;
    };
  argsFor = name: host: {
    inherit inputs;
    username = host.username or username;
    homeDirectory =
      host.homeDirectory
        or "${if host.platform == "darwin" then "/Users" else "/home"}/${host.username or username}";
    fleetInventory = fleet.inventory;
    fleetNames = fleet.hostNames;
    inherit (fleet) workstationNames homeHostNames inputSharingHostNames;
    fleetHostPlatforms = builtins.mapAttrs (_: h: h.platform) fleet.hosts;
    fleetHostUsers = builtins.mapAttrs (_: h: h.username or username) fleet.hosts;
    fleetHostSystems = builtins.mapAttrs (_: h: h.system) fleet.hosts;
    hostFeatures = host.features // {
      hostName = name;
      inherit (host)
        role
        kind
        system
        platform
        desktopStyle
        connectivity
        capabilities
        homeProfiles
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
      aiToolsPackages = import ../packages/ai-tools.nix {
        inherit pkgs;
        llmAgents = inputs.llm-agents.packages.${host.system};
      };
    }
    // lib.optionalAttrs (host.platform == "nixos") {
      herdrPackage = inputs.herdr.packages.${host.system}.default;
      kiroPackages = import ../packages/kiro.nix { inherit pkgs; };
      dbgatePackage = pkgs.callPackage ../packages/dbgate.nix { };
      dbeaverPackage = import ../packages/dbeaver.nix { inherit pkgs; };
    };
  homeModulesFor =
    host:
    let
      platformModule =
        if host.platform == "darwin" then ../profiles/home/darwin.nix else ../profiles/home/linux.nix;
    in
    [
      ../home.nix
      platformModule
      inputs.catppuccin.homeModules.catppuccin
    ]
    ++ lib.optional (host.platform == "nixos") (styleFor host).homeModule
    ++ host.homeModules;
  mkHost =
    name: host:
    let
      style = styleFor host;
      hostUser = host.username or username;
    in
    inputs.nixpkgs.lib.nixosSystem {
      inherit (host) system;
      specialArgs = argsFor name host;
      modules = [
        host.systemModule
      ]
      ++ [
        style.systemModule
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";
          home-manager.users.${hostUser}.imports = homeModulesFor host;
          home-manager.extraSpecialArgs = homeArgsFor name host;
        }
      ];
    };
  mkDarwin =
    name: host:
    let
      hostUser = host.username or username;
    in
    inputs.nix-darwin.lib.darwinSystem {
      specialArgs = argsFor name host;
      modules = [
        ../modules/darwin
        host.systemModule
        inputs.home-manager.darwinModules.home-manager
        {
          nixpkgs.hostPlatform = host.system;
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";
          home-manager.users.${hostUser}.imports = homeModulesFor host;
          home-manager.extraSpecialArgs = homeArgsFor name host;
        }
      ];
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
  inherit mkHost mkDarwin;
  nixosConfigurations = lib.mapAttrs mkHost (lib.getAttrs fleet.nixosHostNames fleet.hosts);
  darwinConfigurations = lib.mapAttrs mkDarwin (lib.getAttrs fleet.darwinHostNames fleet.hosts);
  homeConfigurations = lib.mapAttrs' (
    name: host: lib.nameValuePair "${host.username or username}@${name}" (mkHome name host)
  ) (lib.getAttrs fleet.homeHostNames fleet.hosts);
}
