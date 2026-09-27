{
  hostFeatures,
  lib,
  ...
}:

let
  endpoints = import ../../inventory/endpoints.nix { };
  inputSharing = hostFeatures.inputSharing or { };
  enabled = inputSharing.enable or false;
in

{
  config = lib.mkIf enabled {
    # Lan Mouse is reachable only through the Tailscale interface. The daemon
    # still performs DTLS fingerprint authorization at the application layer.
    networking.firewall.interfaces.tailscale0.allowedUDPPorts = lib.mkAfter [
      endpoints.ports.lanMouse
    ];
  };
}
