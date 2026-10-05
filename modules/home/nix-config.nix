{
  lib,
  pkgs,
  username,
  fleetNames,
  homeHostNames,
  fleetHostPlatforms,
  fleetHostUsers,
  fleetHostSystems,
  ...
}:

let
  commands = import ./nix-config-packages.nix {
    inherit
      lib
      pkgs
      username
      fleetNames
      homeHostNames
      fleetHostPlatforms
      fleetHostUsers
      fleetHostSystems
      ;
  };
in
{
  home.packages = builtins.attrValues commands;
}
