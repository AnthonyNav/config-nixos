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
  config = lib.mkIf enabled {
    assertions = [
      {
        assertion = tailscaleEnabled;
        message = "input sharing requires the host connectivity.tailscale capability.";
      }
    ];

    # Lan Mouse is reachable only through the Tailscale interface. The daemon
    # still performs DTLS fingerprint authorization at the application layer.
    networking.firewall.interfaces.tailscale0.allowedUDPPorts = lib.mkAfter [ 4242 ];
  };
}
