{
  lib,
  pkgs,
  username,
  workstationNames,
  ...
}:

let
  commands = import ./nix-config-packages.nix {
    inherit
      lib
      pkgs
      username
      workstationNames
      ;
  };
in
{
  home.packages = builtins.attrValues commands;
}
