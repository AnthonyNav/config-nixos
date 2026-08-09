{ pkgs, ... }:

{
  imports = [
    ../../modules/home/hyprland.nix
    ../../modules/home/kitty.nix
    ../../modules/home/rofi.nix
    ../../modules/home/night-light.nix
    ../../modules/home/lock-idle.nix
    ../../modules/home/caelestia.nix
    ../../modules/home/caelestia-scheme.nix
    ../../modules/home/theme-mode.nix
    ../../modules/home/monitors.nix
    ../../modules/home/theme-sync.nix
    ../../modules/home/wallpapers.nix
  ];

  home.packages = with pkgs; [
    material-symbols
    nerd-fonts.caskaydia-cove
    rubik
    swappy
    brightnessctl
    qpwgraph
    pavucontrol
    pulseaudio
    grim
    slurp
    wl-clipboard
    cliphist
    hyprpicker
  ];

  # Caelestia renders GTK files dynamically. Home Manager must not own GTK4 CSS.
  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    gtk3.extraConfig."gtk-application-prefer-dark-theme" = 1;
    gtk4.theme = null;
    gtk4.extraConfig."gtk-application-prefer-dark-theme" = 1;
  };

  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
  };

  catppuccin = {
    flavor = "mocha";
    enable = true;
    autoEnable = true;
    # Catppuccin emits Lua that the Hyprlang configuration rejects.
    hyprland.enable = false;
    # Starship already uses the explicit Catppuccin palette in zsh.nix.
    starship.enable = false;
  };
}
