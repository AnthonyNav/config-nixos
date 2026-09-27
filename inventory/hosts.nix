{
  victus = {
    system = "x86_64-linux";
    kind = "workstation";
    # Eligibility does not start services; instances are configured by the host.
    capabilities = {
      kubernetes = true;
      ci = true;
    };
    role = "creative-ml-workstation";
    systemModule = ../hosts/victus;
    homeModules = [ ../hosts/victus/home.nix ];
    desktopStyle = "caelestia";
    connectivity = {
      tailscale = true;
      ssh = true;
      syncthing = true;
    };
    features = {
      virtualizationLab.enable = true;
      gpuCompute.enable = true;
      graphics = "nvidia-prime";
      creativeNvidia = true;
      monitorProfile = "dynamic";
      remoteWorkspace.enable = false;
      inputSharing = {
        enable = true;
        peers = [
          {
            host = "desktop";
            position = "right";
          }
          {
            host = "thinkpad";
            position = "top";
          }
        ];
      };
    };
  };

  desktop = {
    system = "x86_64-linux";
    kind = "workstation";
    # Eligibility does not start services; instances are configured by the host.
    capabilities = {
      kubernetes = true;
      ci = true;
    };
    role = "primary";
    systemModule = ../hosts/desktop;
    homeModules = [ ../hosts/desktop/home.nix ];
    desktopStyle = "caelestia";
    connectivity = {
      tailscale = true;
      ssh = true;
      syncthing = true;
    };
    features = {
      virtualizationLab.enable = true;
      graphics = "nvidia";
      creativeNvidia = true;
      monitorProfile = "desktop-3";
      remoteWorkspace.enable = true;
      inputSharing = {
        enable = true;
        peers = [
          {
            host = "victus";
            position = "left";
          }
          {
            host = "thinkpad";
            position = "right";
          }
        ];
      };
    };
  };

  thinkpad = {
    system = "x86_64-linux";
    kind = "workstation";
    # Eligibility does not start services; instances are configured by the host.
    capabilities = {
      kubernetes = false;
      ci = false;
    };
    role = "workstation";
    systemModule = ../hosts/thinkpad;
    homeModules = [ ../hosts/thinkpad/home.nix ];
    desktopStyle = "caelestia";
    connectivity = {
      tailscale = true;
      ssh = true;
      syncthing = true;
    };
    features = {
      # Explicit opt-in capability; the mobile-development role does not imply VMs.
      virtualizationLab.enable = true;
      graphics = "intel";
      creativeNvidia = false;
      monitorProfile = "dynamic";
      remoteWorkspace.enable = false;
      inputSharing = {
        enable = true;
        peers = [
          {
            host = "desktop";
            position = "left";
          }
          {
            host = "victus";
            position = "bottom";
          }
        ];
      };
    };
  };
}
