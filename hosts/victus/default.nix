{ config, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/system/core.nix
    ../../modules/system/ai-helper.nix
    ../../modules/system/display-manager.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;

  # Workaround para cuelgue del motor de display en idle (HawkPoint RDNA3 + PSR).
  # 0x10 = DC_DISABLE_PSR  /  0x800 = DC_DISABLE_IPS
  # El panel eDP-1 tiene PSR activo; la transición a idle dispara un deadlock en
  # amdgpu_dm_atomic_commit_tail que escala a tormenta de errores DMCUB.
  boot.kernelParams = [ "amdgpu.dcdebugmask=0x810" ];

  # sysrq siempre habilitado para poder hacer REISUB sin habilitar a mano vía SSH.
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
      # Provee el comando `nvidia-offload <app>`: fija las env vars de PRIME
      # (__NV_PRIME_RENDER_OFFLOAD, __GLX_VENDOR_LIBRARY_NAME=nvidia, etc.)
      # para forzar una app puntual a correr en la RTX 4050 en vez del iGPU
      # AMD. Usado por los lanzadores `resolve`/`blender-gpu` (zsh.nix) del
      # stack de edición 3D/video — ver README.md, sección "Edición 3D / Video".
      offload.enableOffloadCmd = true;
      amdgpuBusId = "PCI:6:0:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  system.stateVersion = "24.11";
}
