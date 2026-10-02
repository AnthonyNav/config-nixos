{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.fleet.ai.orca.enable = lib.mkEnableOption "the optional Orca desktop application";

  config.home.packages = lib.optional config.fleet.ai.orca.enable (
    pkgs.callPackage ../../packages/orca-ide.nix { }
  );
}
