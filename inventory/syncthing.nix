{
  managedDevicePrefix = "fleet:";
  managedFolderPrefix = "fleet-";
  reconcileInterval = "10m";

  # `hosts = null` means every workstation with connectivity.syncthing enabled.
  # Paths are relative to the managed user's home directory so the same policy
  # remains portable across hosts.
  folders = {
    shared = {
      id = "fleet-shared";
      label = "Fleet Shared";
      relativePath = "Sync/Fleet";
      type = "sendreceive";
      hosts = null;
    };
  };
}
