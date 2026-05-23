{ pkgs, ... }:

{
  imports = [
    ./modules/home/hyprland.nix
    ./modules/home/waybar.nix
    ./modules/home/hyprpaper.nix
  ];

  home.username = "anthony";
  home.homeDirectory = "/home/anthony";

  home.packages = with pkgs; [
    kitty
    rofi
    dunst
    libnotify
    firefox
    # Tipografía indispensable para que se vean los iconos de la barra (, , etc.)
    nerd-fonts.jetbrains-mono 
  ];

  # ACTIVACIÓN GLOBAL DE CATPPUCCIN
  catppuccin.flavor = "mocha";
  catppuccin.enable = true;

  programs.home-manager.enable = true;
  home.stateVersion = "24.11";
}
