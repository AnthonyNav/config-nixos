{ pkgs, ... }:

{
  services.xserver.enable = true;

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = false;
    theme = "catppuccin-mocha-mauve";
  };

  services.displayManager.defaultSession = "hyprland";

  environment.systemPackages = with pkgs; [
    catppuccin-sddm
    libsForQt5.qt5.qtgraphicaleffects
    libsForQt5.qt5.qtquickcontrols2
    libsForQt5.qt5.qtsvg
  ];

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };
}
