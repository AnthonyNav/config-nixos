{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # 1. Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # 2. Red y Conectividad
  networking.hostName = "victus";
  networking.networkmanager.enable = true;

  # 3. Configuración Regional
  time.timeZone = "America/Mexico_City";
  i18n.defaultLocale = "es_MX.UTF-8";
  console.keyMap = "la-latin1";

  # 4. Características Experimentales
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # 5. Usuario Principal
  users.users.anthony = {
    isNormalUser = true;
    description = "Anthony";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      git
      neovim
      fastfetch
    ];
  };

  # 6. Software Privativo
  nixpkgs.config.allowUnfree = true;

  # 7. Drivers Gráficos (AMD + NVIDIA PRIME)
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

  # 8. Servidor SSH Remoto
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  # 9. Entorno Gráfico Base
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # SOLUCIÓN AL ERROR: Enlazar directorios de aplicaciones y portales compartidos
  environment.pathsToLink = [ "/share/applications" "/share/xdg-desktop-portal" ];

  # Variables de entorno globales
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  system.stateVersion = "24.11";
}
