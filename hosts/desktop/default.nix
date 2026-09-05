{
  config,
  lib,
  pkgs,
  ...
}:
let
  endpoints = import ../../inventory/endpoints.nix;
  desktopEndpoints = endpoints.desktop;
  woodpeckerGrpcPort = endpoints.ports.woodpeckerGrpc;
  privateUiPorts = builtins.map (endpoint: endpoint.tailscalePort) (
    builtins.attrValues desktopEndpoints.privateUis
  );
  privateKubernetesUi =
    {
      name,
      namespace,
      service,
      servicePort,
      localPort,
      tailscalePort,
    }:
    {
      "${name}-forward" = {
        description = "Forward ${name} locally from K3s";
        after = [ "k3s.service" ];
        requires = [ "k3s.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Restart = "always";
          RestartSec = 5;
          ExecStart = "${pkgs.kubectl}/bin/kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml --namespace ${namespace} port-forward --address 127.0.0.1 service/${service} ${toString localPort}:${toString servicePort}";
        };
      };
      "${name}-serve" = {
        description = "Publish ${name} privately through Tailscale Serve";
        after = [
          "${name}-forward.service"
          "tailscaled.service"
        ];
        requires = [ "${name}-forward.service" ];
        wants = [ "tailscaled.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg --yes --https=${toString tailscalePort} http://127.0.0.1:${toString localPort}";
          ExecStop = "${pkgs.tailscale}/bin/tailscale serve --https=${toString tailscalePort} off";
        };
      };
    };
in
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/system
  ];

  networking.hostName = "desktop";

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;

  # Desktop is a single-node K3s host. Do not allow any session or power event
  # to suspend infrastructure workloads while the machine is unattended.
  systemd.sleep.settings.Sleep = {
    AllowSuspend = false;
    AllowHibernation = false;
    AllowHybridSleep = false;
    AllowSuspendThenHibernate = false;
  };

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

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = lib.mkAfter (
    [ endpoints.ports.woodpeckerGrpc ] ++ privateUiPorts
  );
  networking.firewall.interfaces.docker0 = {
    # The Docker-backed Woodpecker agent reaches the server through the bridge.
    # Testcontainers also maps Ryuk onto a host ephemeral port, so its cleanup
    # connection from the job container needs the host's complete ephemeral range.
    allowedTCPPorts = [ woodpeckerGrpcPort ];
    allowedTCPPortRanges = [
      {
        from = 32768;
        to = 60999;
      }
    ];
  };

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
      ExecStart = "${pkgs.kubectl}/bin/kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml --namespace ci port-forward --address 127.0.0.1,172.17.0.1 service/woodpecker-server ${toString woodpeckerGrpcPort}:${toString woodpeckerGrpcPort}";
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
      ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg --yes --tcp=${toString woodpeckerGrpcPort} tcp://127.0.0.1:${toString woodpeckerGrpcPort}";
      ExecStop = "${pkgs.tailscale}/bin/tailscale serve --tcp=${toString woodpeckerGrpcPort} off";
    };
  };

  systemd.services.woodpecker-http-funnel = {
    description = "Publish Woodpecker HTTPS through Tailscale Funnel";
    after = [
      "k3s.service"
      "tailscaled.service"
      "remote-workspace-serve.service"
      "woodpecker-grpc-serve.service"
      "argocd-private-serve.service"
      "grafana-private-serve.service"
      "prometheus-private-serve.service"
      "alertmanager-private-serve.service"
    ];
    partOf = [ "tailscaled.service" ];
    requires = [ "k3s.service" ];
    wants = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = "/etc/woodpecker/agent-desktop.env";

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "5s";
      # Clear both legacy workspace handlers before publishing the only public
      # endpoint. The generic workspace now owns private HTTPS 8448.
      ExecStartPre = [
        "-${pkgs.tailscale}/bin/tailscale serve --https=${toString desktopEndpoints.woodpeckerHttp.httpsPort} off"
        "-${pkgs.tailscale}/bin/tailscale serve --tcp=${toString endpoints.remoteWorkspace.backend.port} off"
      ];
      ExecStart = "${pkgs.tailscale}/bin/tailscale funnel --bg --yes --https=${toString desktopEndpoints.woodpeckerHttp.httpsPort} http://127.0.0.1:80";
      ExecStop = "${pkgs.tailscale}/bin/tailscale funnel --https=${toString desktopEndpoints.woodpeckerHttp.httpsPort} off";
    };
  };

  systemd.services.argocd-private-forward =
    (privateKubernetesUi {
      name = "argocd-private";
      namespace = "argocd";
      service = "argocd-server";
      servicePort = 80;
      localPort = 18080;
      tailscalePort = desktopEndpoints.privateUis.argocd.tailscalePort;
    }).argocd-private-forward;
  systemd.services.argocd-private-serve =
    (privateKubernetesUi {
      name = "argocd-private";
      namespace = "argocd";
      service = "argocd-server";
      servicePort = 80;
      localPort = 18080;
      tailscalePort = desktopEndpoints.privateUis.argocd.tailscalePort;
    }).argocd-private-serve;
  systemd.services.grafana-private-forward =
    (privateKubernetesUi {
      name = "grafana-private";
      namespace = "monitoring";
      service = "monitoring-grafana";
      servicePort = 80;
      localPort = 13000;
      tailscalePort = desktopEndpoints.privateUis.grafana.tailscalePort;
    }).grafana-private-forward;
  systemd.services.grafana-private-serve =
    (privateKubernetesUi {
      name = "grafana-private";
      namespace = "monitoring";
      service = "monitoring-grafana";
      servicePort = 80;
      localPort = 13000;
      tailscalePort = desktopEndpoints.privateUis.grafana.tailscalePort;
    }).grafana-private-serve;
  systemd.services.rabbitmq-private-forward =
    (privateKubernetesUi {
      name = "rabbitmq-private";
      namespace = "develop";
      service = "rabbitmq-dev";
      servicePort = 15672;
      localPort = 15672;
      tailscalePort = desktopEndpoints.privateUis.rabbitmq.tailscalePort;
    }).rabbitmq-private-forward;
  systemd.services.rabbitmq-private-serve =
    (privateKubernetesUi {
      name = "rabbitmq-private";
      namespace = "develop";
      service = "rabbitmq-dev";
      servicePort = 15672;
      localPort = 15672;
      tailscalePort = desktopEndpoints.privateUis.rabbitmq.tailscalePort;
    }).rabbitmq-private-serve;
  systemd.services.prometheus-private-forward =
    (privateKubernetesUi {
      name = "prometheus-private";
      namespace = "monitoring";
      service = "monitoring-prometheus";
      servicePort = 9090;
      localPort = 19090;
      tailscalePort = desktopEndpoints.privateUis.prometheus.tailscalePort;
    }).prometheus-private-forward;
  systemd.services.prometheus-private-serve =
    (privateKubernetesUi {
      name = "prometheus-private";
      namespace = "monitoring";
      service = "monitoring-prometheus";
      servicePort = 9090;
      localPort = 19090;
      tailscalePort = desktopEndpoints.privateUis.prometheus.tailscalePort;
    }).prometheus-private-serve;
  systemd.services.alertmanager-private-forward =
    (privateKubernetesUi {
      name = "alertmanager-private";
      namespace = "monitoring";
      service = "monitoring-alertmanager";
      servicePort = 9093;
      localPort = 19093;
      tailscalePort = desktopEndpoints.privateUis.alertmanager.tailscalePort;
    }).alertmanager-private-forward;
  systemd.services.alertmanager-private-serve =
    (privateKubernetesUi {
      name = "alertmanager-private";
      namespace = "monitoring";
      service = "monitoring-alertmanager";
      servicePort = 9093;
      localPort = 19093;
      tailscalePort = desktopEndpoints.privateUis.alertmanager.tailscalePort;
    }).alertmanager-private-serve;

  # Keep legacy Testcontainers-labelled workflows compatible while allowing
  # this desktop agent to also execute generic workflows.
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
      ExecStart = "${pkgs.docker}/bin/docker run --rm --name=woodpecker-agent-desktop --init --env-file /etc/woodpecker/agent-desktop.env --env WOODPECKER_SERVER=172.17.0.1:${toString woodpeckerGrpcPort} --env WOODPECKER_HOSTNAME=desktop-docker-testcontainers --env WOODPECKER_AGENT_CONFIG_FILE=/etc/woodpecker/agent.conf --env WOODPECKER_BACKEND=docker --env WOODPECKER_AGENT_LABELS=testcontainers=*,repo=AnthonyNav/estoma-services --env WOODPECKER_MAX_WORKFLOWS=2 --mount type=volume,src=woodpecker-agent-desktop-config,dst=/etc/woodpecker --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock woodpeckerci/woodpecker-agent:v3.18.0 agent";
      ExecStop = "${pkgs.docker}/bin/docker stop --time=30 woodpecker-agent-desktop";
    };
  };

  system.stateVersion = "24.11";
}
