# Import this template from hosts.nix only when real Mac facts are available.
# Merely existing here never registers a workstation or network peer.
{
  username,
  homeDirectory ? "/Users/${username}",
}:
{
  inherit username homeDirectory;
  platform = "darwin";
  system = "aarch64-darwin";
  kind = "workstation";
  role = "development-workstation";
  desktopStyle = null;
  homeModules = [ ];
  homeProfiles = [
    "development"
    "platform"
  ];
  systemModule = _: { };
  capabilities = { };
  connectivity = {
    tailscale = true;
    ssh = false;
    syncthing = true;
  };
  features = {
    graphics = "apple";
    orcaRemote.mode = "off";
  };
}
