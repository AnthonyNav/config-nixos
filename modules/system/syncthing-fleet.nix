{
  config,
  fleetInventory,
  hostFeatures,
  lib,
  pkgs,
  username,
  ...
}:

let
  endpoints = import ../../inventory/endpoints.nix { };
  enabled = hostFeatures.connectivity.syncthing or false;
  homeDir = config.users.users.${username}.home;
  shared = import ../../packages/syncthing-fleet.nix {
    inherit pkgs lib fleetInventory;
    inherit (hostFeatures) hostName;
    homeDirectory = homeDir;
  };
  syncthingFleetReconcile = shared.reconcile;

in
{
  assertions = lib.optionals enabled shared.assertions;

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = lib.mkIf enabled (
    lib.mkAfter [ endpoints.ports.syncthing ]
  );

  services.syncthing = lib.mkIf enabled {
    enable = true;
    user = username;
    group = "users";
    dataDir = homeDir;
    configDir = "${homeDir}/.config/syncthing";
    openDefaultPorts = false;
    overrideDevices = false;
    overrideFolders = false;
    inherit (shared) settings;
  };

  users.users.${username}.packages = lib.optionals enabled [ syncthingFleetReconcile ];

  systemd.services.syncthing-fleet-reconcile = lib.mkIf enabled {
    description = "Reconcile declared Syncthing fleet over Tailscale";
    after = [
      "network-online.target"
      "tailscaled.service"
      "syncthing.service"
      "syncthing-init.service"
    ];
    wants = [
      "network-online.target"
      "tailscaled.service"
      "syncthing-init.service"
    ];
    requisite = [ "syncthing.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = username;
      Group = "users";
      Environment = "HOME=${homeDir}";
      ExecStart = lib.getExe syncthingFleetReconcile;
      # The timer retries transient discovery failures without a restart loop.
    };
  };

  systemd.timers.syncthing-fleet-reconcile = lib.mkIf enabled {
    description = "Periodically reconcile declared Syncthing fleet topology";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2m";
      OnUnitActiveSec = shared.reconcileInterval;
      Persistent = true;
      Unit = "syncthing-fleet-reconcile.service";
    };
  };
}
