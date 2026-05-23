{ pkgs, ... }:

{
  imports = [
    ./modules/home/hyprland.nix
    ./modules/home/waybar.nix
    ./modules/home/hyprpaper.nix
    ./modules/home/kitty.nix      # <-- Inyectamos tu nueva terminal optimizada
  ];

  home.username = "anthony";
  home.homeDirectory = "/home/anthony";

  home.packages = with pkgs; [
    rofi
    dunst
    libnotify
    firefox
    nerd-fonts.jetbrains-mono
  ];

  catppuccin.flavor = "mocha";
  catppuccin.enable = true;

  programs.home-manager.enable = true;
  home.stateVersion = "24.11";
}
