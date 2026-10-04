{
  lib,
  pkgs,
  username,
  ...
}:
{
  imports = [
    ./pritunl.nix
    ./ai-helper.nix
    ./input-sharing.nix
    ./gpu-compute.nix
    ./virtualization.nix
  ];
  networking.networkmanager.enable = true;
  users.users.${username}.extraGroups = lib.mkMerge [
    (lib.mkBefore [ "networkmanager" ])
    (lib.mkAfter [
      "video"
      "docker"
      "kvm"
    ])
  ];
  hardware.bluetooth.enable = true;
  services.power-profiles-daemon.enable = true;
  virtualisation.docker.enable = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
  ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
  };
}
