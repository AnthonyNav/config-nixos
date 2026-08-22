{
  managedDevicePrefix = "fleet:";
  managedFolderPrefix = "fleet-";
  reconcileInterval = "10m";

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
