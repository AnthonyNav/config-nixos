{
  hostFeatures,
  lib,
  username,
  ...
}:

let
  policy = import ../../inventory/tailscale.nix { inherit username; };
  connectivity = hostFeatures.connectivity or { };
  tailscaleEnabled = connectivity.tailscale or false;
  sshEnabled = connectivity.ssh or false;
  syncthingEnabled = connectivity.syncthing or false;
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
  ];

  # Port 22 remains reachable only on the tailnet. Tailscale SSH intercepts
  # tailnet port 22 while enabled. The hardened OpenSSH daemon is retained as a
  # physical-console break-glass path: `tailscale set --ssh=false` restores the
  # standard SSH server on the same tailnet port without exposing it globally.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = lib.mkIf tailscaleEnabled (
    lib.mkAfter (lib.optionals sshEnabled [ 22 ])
  );

  services.tailscale = lib.mkIf tailscaleEnabled {
    enable = true;
    openFirewall = false;
    extraSetFlags =
      lib.optionals policy.node.forceHostname [ "--hostname=${hostName}" ]
      ++ lib.optionals (sshEnabled && policy.node.enableSsh) [ "--ssh" ];
  };

  # A newly installed machine may not be authenticated yet when Nix first
  # activates the configuration. Keep retrying the declarative `tailscale set`
  # operation until the node joins the tailnet instead of requiring a second
  # manual activation.
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
