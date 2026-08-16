{
  hostFeatures,
  lib,
  ...
}:

let
  inputSharing = hostFeatures.inputSharing or { };
  enabled = inputSharing.enable or false;
  tailscaleEnabled = (hostFeatures.connectivity or { }).tailscale or false;
in

{
  assertions = lib.optionals enabled [
    {
      assertion = tailscaleEnabled;
      message = "input sharing requires the host connectivity.tailscale capability.";
    }
  ];

  config = lib.mkIf enabled {
    # Lan Mouse is reachable only through the Tailscale interface. The daemon
    # still performs DTLS fingerprint authorization at the application layer.
    networking.firewall.interfaces.tailscale0.allowedUDPPorts = lib.mkAfter [ 4242 ];
  };
}
