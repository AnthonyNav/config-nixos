{ pkgs, ... }:

{
  imports = [
    ./modules/home/hyprland.nix
    ./modules/home/waybar.nix
    ./modules/home/hyprpaper.nix
    ./modules/home/kitty.nix
    ./modules/home/rofi.nix       # <-- Inyectamos tu nuevo Rofi Launcher
  ];

  home.username = "anthony";
  home.homeDirectory = "/home/anthony";

  home.packages = with pkgs; [
    dunst
    libnotify
    firefox
    papirus-icon-theme          # Iconos facheros para el launcher
    nerd-fonts.jetbrains-mono
  ];

  catppuccin.flavor = "mocha";
  catppuccin.enable = true;

  programs.home-manager.enable = true;
  home.stateVersion = "24.11";
}
