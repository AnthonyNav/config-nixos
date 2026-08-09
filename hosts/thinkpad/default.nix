{ ... }:

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

  system.stateVersion = "24.11";
}
