{
  lib,
  pkgs,
  username,
  fleetNames,
  homeHostNames,
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
      ;
  };
in
{
  home.packages = builtins.attrValues commands;
}
