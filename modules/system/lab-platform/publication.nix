{
  config,
  hostFeatures,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.fleet.lab.publication;
  inherit (lib) mkOption types;
  uiType = types.submodule {
    options = {
      namespace = mkOption { type = types.str; };
      service = mkOption { type = types.str; };
      servicePort = mkOption { type = types.port; };
      localPort = mkOption { type = types.port; };
      tailscalePort = mkOption { type = types.port; };
    };
  };
  privateUi = name: ui: {
    "${name}-forward" = {
      description = "Forward ${name} locally from K3s";
      after = [ "k3s.service" ];
      requires = [ "k3s.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Restart = "always";
        RestartSec = 5;
        ExecStart = "${pkgs.kubectl}/bin/kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml --namespace ${ui.namespace} port-forward --address 127.0.0.1 service/${ui.service} ${toString ui.localPort}:${toString ui.servicePort}";
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
        ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg --yes --https=${toString ui.tailscalePort} http://127.0.0.1:${toString ui.localPort}";
        ExecStop = "${pkgs.tailscale}/bin/tailscale serve --https=${toString ui.tailscalePort} off";
      };
    };
  };
  wp = cfg.woodpecker;
  enabled = cfg.privateUis != { } || wp.enable;
in
{
  options.fleet.lab.publication = {
    privateUis = mkOption {
      type = types.attrsOf uiType;
      default = { };
    };
    woodpecker = {
      enable = lib.mkEnableOption "Woodpecker gRPC forwarding through Tailscale";
      environmentFile = mkOption {
        type = types.str;
        default = "/etc/woodpecker/agent.env";
      };
      grpcPort = mkOption {
        type = types.port;
        default = 9000;
      };
      grpcAddresses = mkOption {
        type = types.str;
        default = "127.0.0.1";
      };
      namespace = mkOption {
        type = types.str;
        default = "ci";
      };
      service = mkOption {
        type = types.str;
        default = "woodpecker-server";
      };
      public = {
        enable = lib.mkEnableOption "explicit public HTTPS publication through Tailscale Funnel";
        httpsPort = mkOption {
          type = types.port;
          default = 443;
        };
        backend = mkOption {
          type = types.str;
          default = "http://127.0.0.1:80";
        };
        after = mkOption {
          type = types.listOf types.str;
          default = [ ];
        };
        legacyTcpPorts = mkOption {
          type = types.listOf types.port;
          default = [ ];
        };
      };
    };
  };
  config = lib.mkIf enabled {
    assertions = [
      {
        assertion = config.services.k3s.enable && config.services.k3s.role == "server";
        message = "Local Kubernetes publication requires a K3s server with a local kubeconfig.";
      }
      {
        assertion = config.fleet.lab.kubernetes.autoStart;
        message = "Boot-time publication requires an auto-started Kubernetes instance.";
      }
      {
        assertion = hostFeatures.connectivity.tailscale or false;
        message = "Lab publication requires Tailscale.";
      }
    ];
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = lib.mkAfter (
      lib.optional wp.enable wp.grpcPort
      ++ map (ui: ui.tailscalePort) (builtins.attrValues cfg.privateUis)
    );
    systemd.services = lib.mkMerge [
      (lib.foldl' (a: b: a // b) { } (lib.mapAttrsToList privateUi cfg.privateUis))
      (lib.mkIf wp.enable {
        woodpecker-grpc-forward = {
          description = "Forward Woodpecker gRPC to localhost for Tailscale Serve";
          after = [
            "k3s.service"
            "network-online.target"
          ];
          requires = [ "k3s.service" ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];
          unitConfig.ConditionPathExists = wp.environmentFile;
          serviceConfig = {
            Type = "simple";
            Restart = "always";
            RestartSec = "15s";
            ExecStart = "${pkgs.kubectl}/bin/kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml --namespace ${wp.namespace} port-forward --address ${wp.grpcAddresses} service/${wp.service} ${toString wp.grpcPort}:${toString wp.grpcPort}";
          };
        };
        woodpecker-grpc-serve = {
          description = "Publish Woodpecker gRPC privately through Tailscale Serve";
          after = [
            "tailscaled.service"
            "woodpecker-grpc-forward.service"
          ];
          requires = [ "woodpecker-grpc-forward.service" ];
          wants = [ "tailscaled.service" ];
          wantedBy = [ "multi-user.target" ];
          unitConfig.ConditionPathExists = wp.environmentFile;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg --yes --tcp=${toString wp.grpcPort} tcp://127.0.0.1:${toString wp.grpcPort}";
            ExecStop = "${pkgs.tailscale}/bin/tailscale serve --tcp=${toString wp.grpcPort} off";
          };
        };
        woodpecker-http-funnel = lib.mkIf wp.public.enable {
          description = "Publish Woodpecker HTTPS through Tailscale Funnel";
          after = [
            "k3s.service"
            "tailscaled.service"
          ]
          ++ wp.public.after;
          partOf = [ "tailscaled.service" ];
          requires = [ "k3s.service" ];
          wants = [ "tailscaled.service" ];
          wantedBy = [ "multi-user.target" ];
          unitConfig.ConditionPathExists = wp.environmentFile;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            Restart = "on-failure";
            RestartSec = "5s";
            ExecStartPre = [
              "-${pkgs.tailscale}/bin/tailscale serve --https=${toString wp.public.httpsPort} off"
            ]
            ++ map (
              port: "-${pkgs.tailscale}/bin/tailscale serve --tcp=${toString port} off"
            ) wp.public.legacyTcpPorts;
            ExecStart = "${pkgs.tailscale}/bin/tailscale funnel --bg --yes --https=${toString wp.public.httpsPort} ${wp.public.backend}";
            ExecStop = "${pkgs.tailscale}/bin/tailscale funnel --https=${toString wp.public.httpsPort} off";
          };
        };
      })
    ];
  };
}
