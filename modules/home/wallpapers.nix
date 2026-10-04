{ pkgs, ... }:
{
  # A small reviewed collection, fetched with fixed hashes during the build.
  # Personal images and the old downloaded theme folders remain user-owned.
  home.file."Pictures/Wallpapers/Fleet-Catppuccin".source =
    pkgs.callPackage ../../packages/catppuccin-wallpapers.nix
      { };
}
