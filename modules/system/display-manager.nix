{ pkgs, ... }:

{
  services.xserver.enable = true;

  # Layout compartido: login (SDDM), consola (TTY) e Hyprland usan el mismo toggle.
  # Ambos Shift juntos alternan entre us (inglés) y latam (español latinoamericano).
  services.xserver.xkb = {
    layout = "us,latam";
    variant = ",";
    options = "grp:shifts_toggle,grp_led:scroll";
  };
  console.useXkbConfig = true;

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = false;
    theme = "catppuccin-mocha-mauve";
  };

  services.displayManager.defaultSession = "hyprland";

  environment.systemPackages = with pkgs; [
    catppuccin-sddm
    qt5.qtgraphicaleffects
    qt5.qtquickcontrols2
    qt5.qtsvg
  ];

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };
}
