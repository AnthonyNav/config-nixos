{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/system
  ];

  networking.hostName = "thinkpad";

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Diagnóstico de red local. Los ajustes de ahorro de energía y regulatory
  # domain se prueban después con métricas, no se presuponen como solución.
  environment.systemPackages = with pkgs; [
    pciutils
    iw
    ethtool
    iperf3
    wavemon
  ];

  system.stateVersion = "24.11";
}
