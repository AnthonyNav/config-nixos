{ pkgs, ... }:
{
  programs.mpv.enable = true;
  home.packages =
    with pkgs;
    [
      thunar
      tumbler
      imv
    ]
    ++ [ (pkgs.callPackage ../../packages/sonobus.nix { }) ];
}
