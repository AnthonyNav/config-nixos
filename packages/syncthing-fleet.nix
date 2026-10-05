{
  pkgs,
  lib ? pkgs.lib,
  fleetInventory,
  hostName,
  homeDirectory,
  configDirectory ? "${homeDirectory}/.config/syncthing",
}:
let
  policy = import ../inventory/syncthing.nix;
  port = (import ../inventory/endpoints.nix { }).ports.syncthing;
  hosts = lib.filterAttrs (_: h: h.connectivity.syncthing or false) fleetInventory;
  hostNames = builtins.attrNames hosts;
  folderValues = builtins.attrValues policy.folders;
  folders = map (folder: {
    inherit (folder)
      id
      label
      type
      migrationFrom
      ;
    inherit (policy) ignorePatterns;
    hosts = if folder.hosts == null then hostNames else folder.hosts;
    path = "${homeDirectory}/${folder.relativePath}";
  }) folderValues;
  localFolders = lib.filter (folder: builtins.elem hostName folder.hosts) folders;
  tailscale =
    if pkgs.stdenv.hostPlatform.isDarwin then
      import ./native-tailscale.nix { inherit pkgs; }
    else
      pkgs.tailscale;
in
{
  inherit localFolders;
  inherit (policy) reconcileInterval;
  settings.options = {
    listenAddresses = [ "tcp://0.0.0.0:${toString port}" ];
    globalAnnounceEnabled = false;
    localAnnounceEnabled = false;
    relaysEnabled = false;
    natEnabled = false;
  };
  assertions = [
    {
      assertion = builtins.elem hostName hostNames;
      message = "A Syncthing-enabled host must exist in fleetInventory.";
    }
    {
      assertion =
        builtins.length folderValues == builtins.length (lib.unique (map (f: f.id) folderValues));
      message = "Syncthing folder IDs must be unique.";
    }
    {
      assertion = lib.all (
        f: lib.hasPrefix policy.managedFolderPrefix f.id && !lib.hasPrefix "/" f.relativePath
      ) folderValues;
      message = "Syncthing IDs and relative paths must follow fleet policy.";
    }
    {
      assertion = lib.all (name: builtins.elem name hostNames) (lib.concatMap (f: f.hosts) folders);
      message = "Syncthing folders may reference only eligible fleet hosts.";
    }
  ];
  reconcile = pkgs.writeShellApplication {
    name = "syncthing-fleet-reconcile";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.gawk
      pkgs.gnugrep
      pkgs.jq
      pkgs.libxml2
      pkgs.openssl
      pkgs.python3
      tailscale
    ];
    text = ''
      export SYNCTHING_FLEET_HOST=${lib.escapeShellArg hostName}
      export SYNCTHING_FLEET_PEERS_JSON=${lib.escapeShellArg (builtins.toJSON (lib.remove hostName hostNames))}
      export SYNCTHING_FLEET_FOLDERS_JSON=${lib.escapeShellArg (builtins.toJSON localFolders)}
      export SYNCTHING_CONFIG_DIR=${lib.escapeShellArg configDirectory}
      export SYNCTHING_API_URL=http://127.0.0.1:8384
      export SYNCTHING_MANAGED_DEVICE_PREFIX=${lib.escapeShellArg policy.managedDevicePrefix}
      export SYNCTHING_MANAGED_FOLDER_PREFIX=${lib.escapeShellArg policy.managedFolderPrefix}
      export SYNCTHING_FLEET_IGNORE_HELPER=${lib.escapeShellArg (toString ../scripts/syncthing-ignores.py)}
      ${builtins.readFile ../scripts/syncthing-fleet-reconcile.sh}
    '';
  };
}
