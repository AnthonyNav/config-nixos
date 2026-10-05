{
  hostFeatures,
  lib,
  username,
  ...
}:
let
  cfg = hostFeatures.orcaRemote or { };
  mode = cfg.mode or "off";
  enabled = mode != "off";
  endpoints = import ../../inventory/endpoints.nix { };
in
{
  assertions = [
    {
      assertion = builtins.elem mode [
        "off"
        "desktop-app"
        "headless"
      ];
      message = "Orca Remote supports off, desktop-app and headless.";
    }
    {
      assertion = !enabled || (hostFeatures.connectivity.tailscale or false);
      message = "Orca Remote requires Tailscale connectivity.";
    }
  ];
  # Boot the ordinary user's manager without a graphical login. Home Manager
  # owns the runtime unit; no separate account or copied credentials are needed.
  users.users.${username}.linger = lib.mkDefault (mode == "headless");
  # Pairing address controls advertisement, not the listener's binding.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = lib.mkIf enabled (
    lib.mkAfter [ endpoints.ports.orca ]
  );
}
