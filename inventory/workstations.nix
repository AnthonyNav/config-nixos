{
  victus = {
    role = "workstation";
    systemModule = ../hosts/victus;
    homeModules = [ ../hosts/victus/home.nix ];
    desktopStyle = "caelestia";
    connectivity = {
      tailscale = true;
      ssh = true;
      syncthing = true;
    };
    features = {
      graphics = "nvidia-prime";
      creativeNvidia = true;
      monitorProfile = "dynamic";
      opencodeRemote = {
        enable = true;
      };
      inputSharing = {
        enable = true;
        peers = [ ];
      };
    };
  };

  desktop = {
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
      graphics = "nvidia";
      creativeNvidia = true;
      monitorProfile = "desktop-3";
      opencodeRemote = {
        enable = true;
      };
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
      graphics = "intel";
      creativeNvidia = false;
      monitorProfile = "dynamic";
      opencodeRemote = {
        enable = true;
      };
      inputSharing = {
        enable = true;
        peers = [ ];
      };
    };
  };
}
