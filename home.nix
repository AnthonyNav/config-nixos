{ pkgs, ... }:

{
  imports = [
    ./modules/home/hyprland.nix
    ./modules/home/waybar.nix
    ./modules/home/kitty.nix
    ./modules/home/rofi.nix
    ./modules/home/zsh.nix
    ./modules/home/swaync.nix
  ];

  home.username = "anthony";
  home.homeDirectory = "/home/anthony";

  home.packages = with pkgs; [
    libnotify
    firefox
    papirus-icon-theme
    nerd-fonts.jetbrains-mono

    # --- CONECTIVIDAD Y MULTIMEDIA ---
    networkmanager_dmenu
    overskride
    brightnessctl
    nvtopPackages.amd
    bottom
    nvidia-vaapi-driver
    imv
    mpv
    mpvpaper

    # --- PRODUCTIVIDAD ---
    grim
    slurp
    wl-clipboard
    cliphist
    hyprpicker

    # --- ENTORNO DE DESARROLLO E INGENIERÍA ---
    vscode
    vim
    nano
    neovim

    # Desarrollo Web, Móvil y Emuladores
    android-studio
    flutter
    nodejs_22            # 🛠️ Solución: Mantiene Node.js (que ya incluye corepack internamente)

    # Ciencia de Datos y Python
    python3
    python3Packages.pip
    micromamba

    # Ingeniería de Software C++
    gcc
    gnumake
    cmake
    gdb

    # Ecosistema C# y Backend .NET
    dotnet-sdk_8

    # Utilidades Base
    unzip
    wget
    curl
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
