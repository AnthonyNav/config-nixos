{ config, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/system
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;

  # Workaround para cuelgue del motor de display en idle (HawkPoint RDNA3 + PSR).
  # 0x10 = DC_DISABLE_PSR / 0x800 = DC_DISABLE_IPS.
  boot.kernelParams = [ "amdgpu.dcdebugmask=0x810" ];

  boot.kernel.sysctl."kernel.sysrq" = 1;

  networking.hostName = "victus";

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
      offload.enableOffloadCmd = true;
      amdgpuBusId = "PCI:6:0:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # Victus is a workstation first. Docker remains available through socket
  # activation but no longer consumes resources at boot for CI workloads.
  virtualisation.docker.enableOnBoot = false;

  # Zram remains the fast first tier. This encrypted disk-backed swap is only an
  # emergency buffer for large IDE/ML/creative workloads and cannot hibernate.
  swapDevices = [
    {
      device = "/var/lib/nixos-victus-memory-swapfile";
      size = 8192;
      priority = 0;
      randomEncryption.enable = true;
    }
  ];
  systemd.sleep.settings.Sleep = {
    AllowHibernation = false;
    AllowHybridSleep = false;
    AllowSuspendThenHibernate = false;
  };

  system.stateVersion = "24.11";
}
