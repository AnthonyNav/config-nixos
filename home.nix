{ pkgs, ... }:

{
  imports = [
    ./modules/home/hyprland.nix
    ./modules/home/waybar.nix
    ./modules/home/kitty.nix
    ./modules/home/rofi.nix
    ./modules/home/zsh.nix
    ./modules/home/swaync.nix     # 🌟 Inyectamos el nuevo módulo de widgets avanzados
  ];

  home.username = "anthony";
  home.homeDirectory = "/home/anthony";

  home.packages = with pkgs; [
    libnotify
    firefox
    papirus-icon-theme
    nerd-fonts.jetbrains-mono

    # --- CONECTIVIDAD MODERNA Y ESTÉTICA ---
    networkmanager_dmenu
    overskride
    brightnessctl
    
    # --- MONITORES ---
    nvtopPackages.amd
    bottom

    # --- CIENCIA DE DATOS & IA ---
    nvidia-vaapi-driver

    # --- MULTIMEDIA ---
    imv
    mpv
    mpvpaper

    # --- PRODUCTIVIDAD ---
    grim
    slurp
    wl-clipboard
    cliphist
    hyprpicker
  ];

  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
  };

  programs.btop = {
    enable = true;
    settings = {
      theme_background = false;
      truecolor = true;
    };
  };

  catppuccin.flavor = "mocha";
  catppuccin.enable = true;

  programs.home-manager.enable = true;
  home.stateVersion = "24.11";
}
