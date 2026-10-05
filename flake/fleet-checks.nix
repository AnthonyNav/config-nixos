{
  inputs,
  lib,
  pkgsFor,
  fleet,
  self,
  username,
}:
let
  # A future non-NVIDIA daily device: no server fixture, no production output.
  fixture = fleet.hosts.desktop // {
    role = "daily-workstation";
    homeModules = [ ];
    homeProfiles = [ ];
    features = {
      graphics = "integrated";
      creativeNvidia = false;
      virtualization.enable = false;
      gpuCompute.enable = false;
      inputSharing.enable = false;
    };
    systemModule = { ... }: {
      imports = [ ../modules/system ];
      networking.hostName = "portable-test";
      boot.loader.grub.enable = false;
      fileSystems."/" = {
        device = "none";
        fsType = "tmpfs";
      };
      system.stateVersion = "24.11";
    };
  };
  testFleet = import ../inventory/fleet.nix {
    hosts = fleet.hosts // {
      portable-test = fixture;
    };
  };
  outputs = import ./hosts.nix {
    inherit inputs username;
    fleet = testFleet;
  };
  system = outputs.nixosConfigurations.portable-test.config;
  home = outputs.homeConfigurations."${username}@portable-test".config;
  homes = map (
    name: self.homeConfigurations."${fleet.hosts.${name}.username or username}@${name}".config
  ) fleet.nixosHostNames;
  endpoints = import ../inventory/endpoints.nix { fleet = testFleet; };
  endpointHosts =
    name:
    (lib.findFirst (e: e.name == name) (throw "Missing endpoint ${name}") endpoints.tailnet).hosts;
  invalidFleet = import ../inventory/fleet.nix {
    hosts = {
      invalid = fixture // {
        kind = "server";
      };
    };
  };
  invalidProfiles = outputs.nixosConfigurations.portable-test.extendModules {
    modules = [ { home-manager.users.${username}.fleet.home.profiles = [ "unknown" ]; } ];
  };
  badCreative = import ./hosts.nix {
    inherit inputs username;
    fleet = import ../inventory/fleet.nix {
      hosts.portable-test = fixture // {
        homeProfiles = [ "creative" ];
      };
    };
  };
in
{
  fleet-policy =
    assert fleet.workstationNames == fleet.hostNames && fleet.homeHostNames == fleet.hostNames;
    assert !(builtins.hasAttr "thinkpad" fleet.hosts);
    assert !(builtins.tryEval invalidFleet.hostNames).success;
    assert !(builtins.tryEval invalidProfiles.config.system.build.toplevel.drvPath).success;
    assert
      !(builtins.tryEval
        badCreative.homeConfigurations."${username}@portable-test".activationPackage.drvPath
      ).success;
    assert builtins.elem "portable-test" (endpointHosts "ssh");
    assert builtins.elem "portable-test" (endpointHosts "syncthing");
    assert !(builtins.elem "portable-test" (endpointHosts "lan-mouse"));
    assert home.programs.ssh.settings.desktop.data.User == username;
    assert system.programs.hyprland.enable && system.services.pipewire.enable;
    assert !system.hardware.nvidia-container-toolkit.enable;
    assert !system.virtualisation.libvirtd.enable;
    assert home.fleet.home.profiles == [ ];
    assert home.programs.firefox.enable && home.programs.neovim.enable && home.fleet.ai.orca.enable;
    assert !(home.programs.zsh.shellAliases ? flutter-stop);
    assert lib.all (
      p:
      !(builtins.elem (lib.getName p) [
        "android-studio"
        "flutter"
        "blender"
        "davinci-resolve"
        "jupyterlab"
      ])
    ) home.home.packages;
    assert lib.all (
      c:
      c.fleet.home.profiles == [
        "development"
        "data-science"
        "creative"
        "platform"
      ]
    ) homes;
    assert lib.all (c: builtins.hasAttr "monitor-layout" c.systemd.user.services) homes;
    pkgsFor.runCommand "fleet-policy-check" { } ''touch "$out"'';
}
