{ ... }:
let
  endpoints = import ../../inventory/endpoints.nix { };
  uiPorts = endpoints.desktop.privateUis;
in
{
  fleet.lab = {
    kubernetes = {
      enable = true;
      role = "server";
      clusterInit = true;
      extraFlags = [
        "--write-kubeconfig-mode=0640"
        "--write-kubeconfig-group=wheel"
        "--secrets-encryption"
      ];
      memoryHigh = "10G";
      memoryMax = "12G";
    };
    ci = {
      dockerBridgeGrpcPort = endpoints.ports.woodpeckerGrpc;
      testcontainers = true;
      agents = {
        woodpecker-agent-desktop = {
          description = "Woodpecker Docker agent for Testcontainers on desktop";
          environmentFile = "/etc/woodpecker/agent-desktop.env";
          server = "172.17.0.1:${toString endpoints.ports.woodpeckerGrpc}";
          hostname = "desktop-docker-testcontainers";
          labels = "testcontainers=*,repo=AnthonyNav/estoma-services";
          containerName = "woodpecker-agent-desktop";
          configVolume = "woodpecker-agent-desktop-config";
        };
        woodpecker-agent-frontend = {
          description = "Woodpecker Docker agent for the Estoma frontend on desktop";
          environmentFile = "/etc/woodpecker/agent-frontend.env";
          server = "172.17.0.1:${toString endpoints.ports.woodpeckerGrpc}";
          hostname = "desktop-docker-frontend";
          labels = "repo=AnthonyNav/estoma-app";
          containerName = "woodpecker-agent-frontend";
          configVolume = "woodpecker-agent-frontend-config";
        };
      };
    };
    publication = {
      woodpecker = {
        enable = true;
        environmentFile = "/etc/woodpecker/agent-desktop.env";
        grpcPort = endpoints.ports.woodpeckerGrpc;
        grpcAddresses = "127.0.0.1,172.17.0.1";
        public = {
          enable = true;
          httpsPort = endpoints.desktop.woodpeckerHttp.httpsPort;
          legacyTcpPorts = [ endpoints.remoteWorkspace.backend.port ];
          after = [
            "remote-workspace-serve.service"
            "woodpecker-grpc-serve.service"
            "argocd-private-serve.service"
            "grafana-private-serve.service"
            "prometheus-private-serve.service"
            "alertmanager-private-serve.service"
          ];
        };
      };
      privateUis = {
        argocd-private = {
          namespace = "argocd";
          service = "argocd-server";
          servicePort = 80;
          localPort = 18080;
          tailscalePort = uiPorts.argocd.tailscalePort;
        };
        grafana-private = {
          namespace = "monitoring";
          service = "monitoring-grafana";
          servicePort = 80;
          localPort = 13000;
          tailscalePort = uiPorts.grafana.tailscalePort;
        };
        rabbitmq-private = {
          namespace = "develop";
          service = "rabbitmq-dev";
          servicePort = 15672;
          localPort = 15672;
          tailscalePort = uiPorts.rabbitmq.tailscalePort;
        };
        prometheus-private = {
          namespace = "monitoring";
          service = "monitoring-prometheus";
          servicePort = 9090;
          localPort = 19090;
          tailscalePort = uiPorts.prometheus.tailscalePort;
        };
        alertmanager-private = {
          namespace = "monitoring";
          service = "monitoring-alertmanager";
          servicePort = 9093;
          localPort = 19093;
          tailscalePort = uiPorts.alertmanager.tailscalePort;
        };
      };
    };
  };
}
