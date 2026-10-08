{
  config,
  hostFeatures,
  lib,
  ...
}:
let
  linuxProfiles = {
    development = ./development;
    data-science = ./development/data-science.nix;
    creative = ./creative-production.nix;
    platform = ./platform.nix;
  };
  darwinProfiles = {
    development = ./darwin/development.nix;
    platform = ./platform.nix;
    mobile = ./darwin/mobile.nix;
  };
  profiles = if hostFeatures.platform == "darwin" then darwinProfiles else linuxProfiles;
  selected = hostFeatures.homeProfiles;
in
{
  imports = [
    ./base.nix
    ./identities.nix
    ./fleet-access.nix
    ./development/ai.nix
    ../../modules/home/workspace-sync.nix
  ]
  ++ map (name: profiles.${name} or (throw "Unknown Home profile '${name}'.")) selected;

  options.fleet.home.profiles = lib.mkOption {
    type = lib.types.listOf (lib.types.enum (builtins.attrNames profiles));
    readOnly = true;
    description = "Explicit functional profiles, independent of the machine name.";
  };
  config.fleet.home.profiles = selected;
  config.assertions = [
    {
      assertion = config.fleet.home.profiles == selected;
      message = "Home profiles must be selected through the inventory.";
    }
    {
      assertion = builtins.length selected == builtins.length (lib.unique selected);
      message = "Home profiles must be unique.";
    }
  ];
}
