{
  fleetInventory,
  hostFeatures,
  lib,
  pkgs,
  username,
  ...
}:

let
  endpoints = import ../../inventory/endpoints.nix;
  policy = import ../../inventory/syncthing.nix;
  connectivity = hostFeatures.connectivity or { };
  enabled = connectivity.syncthing or false;
  hostName = hostFeatures.hostName or "";
  homeDir = "/home/${username}";

  syncthingHosts = lib.filterAttrs (_: host: (host.connectivity.syncthing or false)) fleetInventory;
  syncthingHostNames = builtins.attrNames syncthingHosts;
  peerNames = lib.remove hostName syncthingHostNames;

  folderValues = builtins.attrValues policy.folders;
  folderIds = map (folder: folder.id) folderValues;
  normalizedFolders = map (
    folder:
    let
      hosts = if folder.hosts == null then syncthingHostNames else folder.hosts;
    in
    {
      inherit (folder) id label type;
      inherit hosts;
      path = "${homeDir}/${folder.relativePath}";
    }
  ) folderValues;
  localFolders = lib.filter (folder: builtins.elem hostName folder.hosts) normalizedFolders;
  declaredFolderHosts = lib.concatLists (map (folder: folder.hosts) normalizedFolders);

  syncthingFleetReconcile = pkgs.writeShellApplication {
    name = "syncthing-fleet-reconcile";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      gawk
      gnugrep
      jq
      libxml2
      openssl
      tailscale
    ];
    text = ''
      export SYNCTHING_FLEET_HOST=${lib.escapeShellArg hostName}
      export SYNCTHING_FLEET_PEERS_JSON=${lib.escapeShellArg (builtins.toJSON peerNames)}
      export SYNCTHING_FLEET_FOLDERS_JSON=${lib.escapeShellArg (builtins.toJSON localFolders)}
      export SYNCTHING_CONFIG_DIR=${lib.escapeShellArg "${homeDir}/.config/syncthing"}
      export SYNCTHING_API_URL=http://127.0.0.1:8384
      export SYNCTHING_MANAGED_DEVICE_PREFIX=${lib.escapeShellArg policy.managedDevicePrefix}
      export SYNCTHING_MANAGED_FOLDER_PREFIX=${lib.escapeShellArg policy.managedFolderPrefix}
      ${builtins.readFile ../../scripts/syncthing-fleet-reconcile.sh}
    '';
  };
in
{
  assertions = lib.optionals enabled [
    {
      assertion = builtins.elem hostName syncthingHostNames;
      message = "A Syncthing-enabled host must exist in fleetInventory.";
    }
    {
      assertion = builtins.length folderIds == builtins.length (lib.unique folderIds);
      message = "Syncthing managed folder IDs must be unique.";
    }
    {
      assertion = builtins.all (folder: lib.hasPrefix policy.managedFolderPrefix folder.id) folderValues;
      message = "Syncthing managed folder IDs must use the declared managedFolderPrefix.";
    }
    {
      assertion = builtins.all (folder: !(lib.hasPrefix "/" folder.relativePath)) folderValues;
      message = "Syncthing managed folder paths must be relative to the user's home directory.";
    }
    {
      assertion = builtins.all (name: builtins.elem name syncthingHostNames) declaredFolderHosts;
      message = "Syncthing folders may reference only Syncthing-enabled fleet hosts.";
    }
  ];

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
    settings.options = {
      listenAddresses = [ "tcp://0.0.0.0:${toString endpoints.ports.syncthing}" ];
      globalAnnounceEnabled = false;
      localAnnounceEnabled = false;
      relaysEnabled = false;
      natEnabled = false;
    };
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
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };

  systemd.timers.syncthing-fleet-reconcile = lib.mkIf enabled {
    description = "Periodically reconcile declared Syncthing fleet topology";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2m";
      OnUnitActiveSec = policy.reconcileInterval;
      Persistent = true;
      Unit = "syncthing-fleet-reconcile.service";
    };
  };
}
