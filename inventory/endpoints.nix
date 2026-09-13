let
  workstationNames = [
    "desktop"
    "thinkpad"
    "victus"
  ];
  ports = {
    ssh = 22;
    syncthing = 22000;
    lanMouse = 4242;
    woodpeckerGrpc = 9000;
    woodpeckerHttp = 443;
    remoteWorkspace.desktop = 8448;
    desktopUis = {
      argocd = 8443;
      grafana = 8444;
      prometheus = 8445;
      alertmanager = 8446;
      rabbitmq = 8447;
    };
  };
in
{
  inherit ports workstationNames;

  remoteWorkspace = {
    backend = {
      hostname = "127.0.0.1";
      port = 8082;
    };
    hosts.desktop.httpsPort = ports.remoteWorkspace.desktop;
    configFile = ".config/remote-workspace/zellij.kdl";
  };

  desktop = {
    woodpeckerHttp = {
      httpsPort = ports.woodpeckerHttp;
      visibility = "public";
    };
    privateUis = {
      argocd.tailscalePort = ports.desktopUis.argocd;
      grafana.tailscalePort = ports.desktopUis.grafana;
      prometheus.tailscalePort = ports.desktopUis.prometheus;
      alertmanager.tailscalePort = ports.desktopUis.alertmanager;
      rabbitmq.tailscalePort = ports.desktopUis.rabbitmq;
    };
  };

  # These declarations are the source of truth for tailnet grants. Modules
  # still own their corresponding firewall and Tailscale Serve/Funnel units.
  tailnet = [
    {
      name = "ssh";
      protocol = "tcp";
      port = ports.ssh;
      hosts = workstationNames;
    }
    {
      name = "remote-workspace-desktop";
      protocol = "tcp";
      port = ports.remoteWorkspace.desktop;
      hosts = [ "desktop" ];
    }
    {
      name = "woodpecker-grpc";
      protocol = "tcp";
      port = ports.woodpeckerGrpc;
      hosts = [ "desktop" ];
    }
    {
      name = "syncthing";
      protocol = "tcp";
      port = ports.syncthing;
      hosts = workstationNames;
    }
    {
      name = "lan-mouse";
      protocol = "udp";
      port = ports.lanMouse;
      hosts = workstationNames;
    }
  ]
  ++ builtins.map (name: {
    inherit name;
    protocol = "tcp";
    port = ports.desktopUis.${name};
    hosts = [ "desktop" ];
  }) (builtins.attrNames ports.desktopUis);

  public = [
    {
      name = "woodpecker-http";
      protocol = "tcp";
      port = ports.woodpeckerHttp;
      hosts = [ "desktop" ];
    }
  ];
}
