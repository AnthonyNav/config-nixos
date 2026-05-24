{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # 1. Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;

  # 2. Red y Conectividad
  networking.hostName = "victus";
  networking.networkmanager.enable = true;

  # 3. Configuración Regional Base
  time.timeZone = "America/Mexico_City";
  i18n.defaultLocale = "es_MX.UTF-8";
  console.keyMap = "us";

  # 4. Características Experimentales
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  programs.zsh.enable = true;

  # 5. Usuario Principal
  users.users.anthony = {
    isNormalUser = true;
    description = "Anthony";
    shell = pkgs.zsh;
    extraGroups = [ "networkmanager" "wheel" "video" ];
    packages = with pkgs; [
      git
      neovim
      fastfetch
    ];
  };

  # 6. Software Privativo
  nixpkgs.config.allowUnfree = true;

  # 7. Drivers Gráficos (AMD + NVIDIA PRIME)
  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    prime = {
      offload.enable = true;
      amdgpuBusId = "PCI:6:0:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # 8. Servicios de Hardware Esenciales
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };
  
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
  services.power-profiles-daemon.enable = true;

  # CORRECCIÓN DE SDDM
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = false;
    theme = "catppuccin-mocha-mauve"; # 🛠️ Nombre corregido según la ruta real
  };
  services.displayManager.defaultSession = "hyprland"; # 🛠️ Sesión exacta en minúsculas

  # Paquetes globales y dependencias QML
  environment.systemPackages = with pkgs; [
    catppuccin-sddm
    libsForQt5.qt5.qtgraphicaleffects
    libsForQt5.qt5.qtquickcontrols2
    libsForQt5.qt5.qtsvg
  ];

  # 9. Entorno Gráfico Base
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  environment.pathsToLink = [ "/share/applications" "/share/xdg-desktop-portal" ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
  };

  system.stateVersion = "24.11";
}
