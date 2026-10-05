let
  # One daily environment. Hosts only select capabilities and hardware modules.
  workstation = {
    system = "x86_64-linux";
    platform = "nixos";
    kind = "workstation";
    role = "creative-ml-workstation";
    capabilities = { };
    homeModules = [ ];
    homeProfiles = [
      "development"
      "data-science"
      "creative"
      "platform"
    ];
    desktopStyle = "caelestia";
    connectivity = {
      tailscale = true;
      ssh = true;
      syncthing = true;
    };
  };
in
{
  desktop = workstation // {
    systemModule = ../hosts/desktop;
    homeModules = [ ../hosts/desktop/home.nix ];
    features = {
      orcaRemote = {
        mode = "headless";
        preferredRuntime = true;
      };
      virtualization.enable = true;
      gpuCompute.enable = true;
      graphics = "nvidia";
      creativeNvidia = true;
      inputSharing = {
        enable = true;
        peers = [
          {
            host = "victus";
            position = "left";
          }
        ];
      };
    };
  };
  victus = workstation // {
    systemModule = ../hosts/victus;
    features = {
      orcaRemote = {
        mode = "off";
        preferredRuntime = false;
      };
      virtualization.enable = true;
      gpuCompute.enable = true;
      graphics = "nvidia-prime";
      creativeNvidia = true;
      inputSharing = {
        enable = true;
        peers = [
          {
            host = "desktop";
            position = "right";
          }
        ];
      };
    };
  };
}
