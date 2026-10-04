{ lib, pkgs, ... }:
let
  standalone = pkgs.callPackage ../../packages/blender-standalone.nix { };
in
{
  # The official archive is verified during the build. Old local copies and
  # user data are preserved; activation no longer downloads or replaces them.
  home.packages = [ (lib.hiPrio standalone) ];
}
