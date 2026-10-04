{ config, username, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/system
  ];

  networking.hostName = "desktop";

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;

  # Interactive workstation: ordinary suspend is available again.
  systemd.sleep.settings.Sleep = {
    AllowSuspend = true;
    AllowHibernation = false;
    AllowHybridSleep = false;
    AllowSuspendThenHibernate = false;
  };

  # Keep Docker available for development without starting it at boot.
  virtualisation.docker.enableOnBoot = false;

  # Explicitly retire the linger marker used by the persistent web terminal.
  users.users.${username}.linger = false;

  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # GeForce RTX 3060 Ti (GA104, Ampere) sobre un i5-12400F: el sufijo F
  # confirma que este CPU no tiene iGPU, así que a diferencia de victus
  # (laptop híbrida AMD+NVIDIA) aquí no existe `hardware.nvidia.prime` —
  # no hay un segundo GPU al cual hacerle offload, la RTX ya es el único
  # renderizador del sistema. Ver modules/home/zsh.nix (`gpu-launch`) para
  # cómo los lanzadores de DaVinci/Blender se adaptan a esto en runtime.
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  system.stateVersion = "24.11";
}
