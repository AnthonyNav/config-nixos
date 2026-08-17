{
  config,
  hostFeatures,
  lib,
  pkgs,
  username,
  ...
}:

let
  policy = import ../../inventory/opencode-remote.nix;
  tailscalePolicy = (import ../../inventory/tailscale.nix { inherit username; }).tailnetPolicy;
  connectivity = hostFeatures.connectivity or { };
  remote = hostFeatures.opencodeRemote or { };
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
      message = "Remote OpenCode requires connectivity.tailscale.";
    }
    {
      assertion = policy.backend.hostname == "127.0.0.1";
      message = "Remote OpenCode must remain localhost-only behind Tailscale Serve.";
    }
    {
      assertion = backendPort != httpsPort;
      message = "Remote OpenCode backend and Tailscale Serve ports must remain distinct.";
    }
    {
      assertion = config.users.users.${username}.linger;
      message = "Remote OpenCode requires systemd user linger for boot-time persistence.";
    }
    {
      assertion = builtins.elem httpsPort tailscaleTcpPorts;
      message = "Remote OpenCode HTTPS must be allowed on tailscale0.";
    }
    {
      assertion =
        !(builtins.elem backendPort globalTcpPorts) && !(builtins.elem backendPort tailscaleTcpPorts);
      message = "Remote OpenCode backend port must never be exposed through the NixOS firewall.";
    }
    {
      assertion = builtins.elem "tcp:${toString httpsPort}" grant.ip;
      message = "The declared tailnet policy must authorize Remote OpenCode HTTPS.";
    }
  ];

  # Linger makes the user's systemd manager start at boot and survive logout,
  # so phone/browser disconnects do not own the lifetime of OpenCode jobs.
  users.users.${username}.linger = lib.mkIf enabled true;

  # The OpenCode backend port is intentionally never opened. Only Tailscale's
  # private HTTPS listener is reachable over tailscale0.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = lib.mkIf enabled (
    lib.mkAfter [ httpsPort ]
  );

  systemd.services.opencode-remote-serve = lib.mkIf enabled {
    description = "Publish OpenCode Web privately through Tailscale Serve";
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
