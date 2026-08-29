{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/system
  ];

  networking.hostName = "desktop";

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;

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

  environment.systemPackages = [ pkgs.kubectl ];

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = lib.mkAfter [ 9000 ];

  services.k3s = {
    enable = true;
    package = pkgs.k3s_1_36;
    role = "server";
    clusterInit = true;
    extraFlags = [
      "--write-kubeconfig-mode=0640"
      "--write-kubeconfig-group=wheel"
      "--secrets-encryption"
    ];
  };

  # Keep capacity available for the interactive desktop while allowing the
  # cluster to host the current single-node workload.
  systemd.services.k3s.serviceConfig = {
    MemoryHigh = "10G";
    MemoryMax = "12G";
  };

  # The forward remains localhost-only. Tailscale Serve publishes its TCP
  # endpoint privately after Woodpecker has been restored into this cluster.
  systemd.services.woodpecker-grpc-forward = {
    description = "Forward Woodpecker gRPC to localhost for Tailscale Serve";
    after = [
      "k3s.service"
      "network-online.target"
    ];
    requires = [ "k3s.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = "/etc/woodpecker/agent-desktop.env";

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "15s";
      ExecStart = "${pkgs.kubectl}/bin/kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml --namespace ci port-forward --address 127.0.0.1 service/woodpecker-server 9000:9000";
    };
  };

  systemd.services.woodpecker-grpc-serve = {
    description = "Publish Woodpecker gRPC privately through Tailscale Serve";
    after = [
      "tailscaled.service"
      "woodpecker-grpc-forward.service"
    ];
    requires = [ "woodpecker-grpc-forward.service" ];
    wants = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = "/etc/woodpecker/agent-desktop.env";

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg --yes --tcp=9000 tcp://127.0.0.1:9000";
      ExecStop = "${pkgs.tailscale}/bin/tailscale serve --tcp=9000 off";
    };
  };

  # This agent is dormant until its per-agent token is installed locally.
  # Preserve the capability label during the victus-to-desktop migration so
  # existing Testcontainers workflows continue to select the replacement.
  systemd.services.woodpecker-agent-desktop = {
    description = "Woodpecker Docker agent for Testcontainers on desktop";
    after = [
      "docker.service"
      "network-online.target"
    ];
    requires = [ "docker.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = "/etc/woodpecker/agent-desktop.env";

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      TimeoutStopSec = "45s";
      ExecStartPre = "-${pkgs.docker}/bin/docker rm --force woodpecker-agent-desktop";
      ExecStart = "${pkgs.docker}/bin/docker run --rm --name=woodpecker-agent-desktop --init --env-file /etc/woodpecker/agent-desktop.env --env WOODPECKER_SERVER=desktop.tail88c098.ts.net:9000 --env WOODPECKER_HOSTNAME=desktop-docker-testcontainers --env WOODPECKER_AGENT_CONFIG_FILE=/etc/woodpecker/agent.conf --env WOODPECKER_BACKEND=docker --env WOODPECKER_AGENT_LABELS=!testcontainers=victus,repo=AnthonyNav/estoma-services --env WOODPECKER_MAX_WORKFLOWS=1 --mount type=volume,src=woodpecker-agent-desktop-config,dst=/etc/woodpecker --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock woodpeckerci/woodpecker-agent:v3.18.0 agent";
      ExecStop = "${pkgs.docker}/bin/docker stop --time=30 woodpecker-agent-desktop";
    };
  };

  system.stateVersion = "24.11";
}
