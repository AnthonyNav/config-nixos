{
  hostFeatures,
  lib,
  username,
  ...
}:

let
  endpoints = import ../../inventory/endpoints.nix { };
  policy = import ../../inventory/tailscale.nix { inherit username; };
  connectivity = hostFeatures.connectivity or { };
  inputSharing = hostFeatures.inputSharing or { };
  tailscaleEnabled = connectivity.tailscale or false;
  sshEnabled = connectivity.ssh or false;
  syncthingEnabled = connectivity.syncthing or false;
  inputSharingEnabled = inputSharing.enable or false;
  orcaRemoteEnabled = (hostFeatures.orcaRemote.mode or "off") != "off";
  requiresIncoming = sshEnabled || syncthingEnabled || inputSharingEnabled || orcaRemoteEnabled;
  hostName = hostFeatures.hostName or "";
in
{
  assertions = [
    {
      assertion = !sshEnabled || tailscaleEnabled;
      message = "connectivity.ssh requires connectivity.tailscale.";
    }
    {
      assertion = !syncthingEnabled || tailscaleEnabled;
      message = "connectivity.syncthing requires connectivity.tailscale.";
    }
    {
      assertion = !tailscaleEnabled || hostName != "";
      message = "A Tailscale-enabled fleet host must have a declared hostName.";
    }
    {
      assertion = !sshEnabled || policy.node.enableSsh;
      message = "SSH-capable fleet hosts require Tailscale SSH in the declared fleet policy.";
    }
    {
      assertion = !requiresIncoming || policy.node.allowIncoming;
      message = "SSH, Syncthing, input sharing and Orca Remote require incoming Tailscale connections.";
    }
  ];

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = lib.mkIf tailscaleEnabled (
    lib.mkAfter (lib.optionals sshEnabled [ endpoints.ports.ssh ])
  );

  services.tailscale = lib.mkIf tailscaleEnabled {
    enable = true;
    openFirewall = false;
    extraSetFlags =
      lib.optionals policy.node.forceHostname [ "--hostname=${hostName}" ]
      ++ lib.optionals policy.node.allowIncoming [ "--shields-up=false" ]
      ++ lib.optionals (sshEnabled && policy.node.enableSsh) [ "--ssh" ];
  };

  systemd.services.tailscaled-set.serviceConfig = lib.mkIf tailscaleEnabled {
    Restart = "on-failure";
    RestartSec = "15s";
  };

  services.openssh = lib.mkIf sshEnabled {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
}
