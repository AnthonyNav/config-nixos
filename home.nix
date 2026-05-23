{ pkgs, ... }:

{
  imports = [
    ./modules/home/hyprland.nix
    ./modules/home/waybar.nix
    ./modules/home/hyprpaper.nix
    ./modules/home/kitty.nix
    ./modules/home/rofi.nix
  ];

  home.username = "anthony";
  home.homeDirectory = "/home/anthony";

  home.packages = with pkgs; [
    libnotify
    firefox
    papirus-icon-theme
    nerd-fonts.jetbrains-mono
  ];

  # Activamos Dunst de forma nativa para que Catppuccin lo configure solo
  services.dunst.enable = true;

  catppuccin.flavor = "mocha";
  catppuccin.enable = true;

  programs.home-manager.enable = true;
  home.stateVersion = "24.11";
}
