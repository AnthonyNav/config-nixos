{ hostFeatures, lib, ... }:
let
  cfg = hostFeatures.orcaRemote or { };
  mode = cfg.mode or "off";
  enabled = mode == "desktop-app";
  endpoints = import ../../inventory/endpoints.nix { };
in
{
  assertions = [
    {
      assertion = builtins.elem mode [
        "off"
        "desktop-app"
      ];
      message = "Orca Remote supports off/desktop-app. Headless requires a separate validated recovery design.";
    }
    {
      assertion = !enabled || (hostFeatures.connectivity.tailscale or false);
      message = "Orca Remote requires Tailscale connectivity.";
    }
  ];
  # Only prepare access for the explicitly chosen app mode. App startup,
  # pairing tokens and credentials remain mutable user actions.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = lib.mkIf enabled (
    lib.mkAfter [ endpoints.ports.orca ]
  );
}
