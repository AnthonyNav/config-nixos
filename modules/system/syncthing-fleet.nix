{
  fleetInventory,
  hostFeatures,
  lib,
  username,
  ...
}:

let
  policy = import ../../inventory/syncthing.nix;
  connectivity = hostFeatures.connectivity or { };
  enabled = connectivity.syncthing or false;
  hostName = hostFeatures.hostName or "";

  syncthingHosts = lib.filterAttrs (
    _: host: (host.connectivity.syncthing or false)
  ) fleetInventory;
  syncthingHostNames = builtins.attrNames syncthingHosts;

  folderValues = builtins.attrValues policy.folders;
  folderIds = map (folder: folder.id) folderValues;
  declaredFolderHosts = lib.concatLists (
    map (
      folder:
      if folder.hosts == null then syncthingHostNames else folder.hosts
    ) folderValues
  );
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

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = lib.mkIf enabled (lib.mkAfter [ 22000 ]);

  services.syncthing = lib.mkIf enabled {
    enable = true;
    user = username;
    group = "users";
    dataDir = "/home/${username}";
    configDir = "/home/${username}/.config/syncthing";
    openDefaultPorts = false;

    # Fleet-managed state is reconciled separately. Keep unrelated/manual
    # Syncthing devices and folders intact during the migration.
    overrideDevices = false;
    overrideFolders = false;

    # All peer discovery and transport is provided by Tailscale. Disabling
    # Syncthing's Internet/LAN discovery, relays and NAT traversal prevents the
    # daemon from creating alternate paths outside the tailnet.
    settings.options = {
      listenAddresses = [ "tcp://0.0.0.0:22000" ];
      globalAnnounceEnabled = false;
      localAnnounceEnabled = false;
      relaysEnabled = false;
      natEnabled = false;
    };
  };
}
