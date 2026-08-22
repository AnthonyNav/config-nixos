{
  config,
  hostFeatures,
  lib,
  pkgs,
  username,
  ...
}:

let
  policy = import ../../inventory/remote-workspace.nix;
  tailscalePolicy = (import ../../inventory/tailscale.nix { inherit username; }).tailnetPolicy;
  connectivity = hostFeatures.connectivity or { };
  remote = hostFeatures.remoteWorkspace or { };
  enabled = remote.enable or false;
  tailscaleEnabled = connectivity.tailscale or false;
  httpsPort = policy.serve.httpsPort;
  backendPort = policy.backend.port;
  backendUrl = "http://${policy.backend.hostname}:${toString backendPort}";
  grant = builtins.head tailscalePolicy.grants;
  globalTcpPorts = config.networking.firewall.allowedTCPPorts or [ ];
  tailscaleTcpPorts = config.networking.firewall.interfaces.tailscale0.allowedTCPPorts or [ ];
in
{
  assertions = lib.optionals enabled [
    {
      assertion = tailscaleEnabled;
      message = "features.remoteWorkspace requires connectivity.tailscale.";
    }
    {
      assertion = policy.backend.hostname == "127.0.0.1";
      message = "The remote workspace backend must remain localhost-only behind Tailscale Serve.";
    }
    {
      assertion = backendPort != httpsPort;
      message = "Remote workspace backend and Tailscale Serve ports must remain distinct.";
    }
    {
      assertion = config.users.users.${username}.linger;
      message = "The remote workspace requires systemd user linger for boot-time persistence.";
    }
    {
      assertion = builtins.elem httpsPort tailscaleTcpPorts;
      message = "Remote workspace HTTPS must be allowed on tailscale0.";
    }
    {
      assertion =
        !(builtins.elem backendPort globalTcpPorts) && !(builtins.elem backendPort tailscaleTcpPorts);
      message = "The remote workspace backend port must never be exposed by the host firewall.";
    }
    {
      assertion = builtins.elem "tcp:${toString httpsPort}" grant.ip;
      message = "The tailnet policy must authorize remote workspace HTTPS.";
    }
  ];

  users.users.${username}.linger = lib.mkIf enabled true;

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = lib.mkIf enabled (
    lib.mkAfter [ httpsPort ]
  );

  systemd.services.remote-workspace-serve = lib.mkIf enabled {
    description = "Publish the generic remote workspace privately through Tailscale Serve";
    after = [
      "tailscaled.service"
      "tailscaled-set.service"
    ];
    wants = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg --yes --https=${toString httpsPort} ${backendUrl}";
      ExecStop = "${pkgs.tailscale}/bin/tailscale serve --https=${toString httpsPort} off";
      Restart = "on-failure";
      RestartSec = "30s";
    };
  };
}
