{ pkgs, ... }:
{
  programs.firefox = {
    enable = true;
    # Preserve existing profiles/bookmarks; do not silently migrate directories.
    configPath = ".mozilla/firefox";
  };
  home.packages = [ pkgs.google-chrome ];
}
