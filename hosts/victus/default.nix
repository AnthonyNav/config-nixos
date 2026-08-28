{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/system
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

  # This agent is the only Docker-socket consumer in the fleet. Its mandatory
  # labels keep ordinary CI work on the Kubernetes agent.
  systemd.services.woodpecker-agent-victus = {
    description = "Woodpecker Docker agent for Testcontainers on victus";
    after = [
      "docker.service"
      "network-online.target"
    ];
    requires = [ "docker.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = "/etc/woodpecker/agent-victus.env";

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      TimeoutStopSec = "45s";
      ExecStartPre = "-${pkgs.docker}/bin/docker rm --force woodpecker-agent-victus";
      ExecStart = "${pkgs.docker}/bin/docker run --rm --name=woodpecker-agent-victus --init --env-file /etc/woodpecker/agent-victus.env --env WOODPECKER_SERVER=100.80.44.83:9000 --env WOODPECKER_HOSTNAME=victus-docker-testcontainers --env WOODPECKER_AGENT_CONFIG_FILE=/etc/woodpecker/agent.conf --env WOODPECKER_BACKEND=docker --env WOODPECKER_AGENT_LABELS=!testcontainers=victus,repo=AnthonyNav/estoma-services --env WOODPECKER_MAX_WORKFLOWS=1 --mount type=volume,src=woodpecker-agent-victus-config,dst=/etc/woodpecker --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock woodpeckerci/woodpecker-agent:v3.18.0 agent";
      ExecStop = "${pkgs.docker}/bin/docker stop --time=30 woodpecker-agent-victus";
    };
  };

  system.stateVersion = "24.11";
}
