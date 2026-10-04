{ config, pkgs, ... }:
{
  catppuccin.rofi.enable = false;
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    settings = {
      modi = "drun,run";
      show-icons = true;
      icon-theme = "Papirus";
      drun-display-format = "{name}";
      disable-history = false;
      sidebar-mode = false;
    };
    theme = "${config.xdg.stateHome}/caelestia/theme/rofi.rasi";
  };
}
