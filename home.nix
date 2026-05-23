{ pkgs, ... }:

{
  imports = [
    ./modules/home/hyprland.nix
  ];

  home.username = "anthony";
  home.homeDirectory = "/home/anthony";

  home.packages = with pkgs; [
    kitty
    waybar
    rofi
    dunst
    libnotify
    
    # --- KIT DE SUPERVIVENCIA ---
    firefox          # Tu navegador principal
    hyprpaper        # Para gestionar tus fondos de pantalla
  ];

  programs.home-manager.enable = true;
  home.stateVersion = "24.11";
}
