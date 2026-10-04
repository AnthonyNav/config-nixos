{
  inputs,
  lib,
  pkgsFor,
  fleet,
  self,
  username,
}:
let
  # Synthetic build fixture only: never exported as a deployable fleet host.
  server = {
    system = "x86_64-linux";
    kind = "server";
    role = "headless-test";
    desktopStyle = null;
    homeModules = null;
    capabilities = {
      kubernetes = false;
      ci = false;
    };
    connectivity = {
      tailscale = true;
      ssh = true;
      syncthing = false;
    };
    features = { };
    systemModule = { ... }: {
      imports = [ ../modules/system ];
      networking.hostName = "server-test";
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
      server-test = server;
    };
  };
  testOutputs = import ./hosts.nix {
    inherit inputs username;
    fleet = testFleet;
  };
  headless = testOutputs.nixosConfigurations.server-test;
  c = headless.config;
  testEndpoints = import ../inventory/endpoints.nix { fleet = testFleet; };
  home = testOutputs.homeConfigurations."${username}@thinkpad".config;
  endpointHosts =
    name:
    (lib.findFirst (e: e.name == name) (throw "Missing endpoint ${name}") testEndpoints.tailnet).hosts;
  k8s = self.nixosConfigurations.victus.extendModules {
    modules = [
      {
        fleet.lab.kubernetes = {
          enable = true;
          autoStart = false;
          clusterInit = true;
        };
      }
    ];
  };
  runner = self.nixosConfigurations.victus.extendModules {
    modules = [
      {
        fleet.lab.ci.agents.lab-agent = {
          description = "CI test instance";
          environmentFile = "/run/secrets/lab-agent";
          server = "lab-server:9000";
          hostname = "victus-lab-test";
          labels = "repo=example/lab";
          containerName = "victus-lab-test";
          configVolume = "victus-lab-test-config";
          autoStart = false;
        };
      }
    ];
  };
  invalidK8s = headless.extendModules { modules = [ { fleet.lab.kubernetes.enable = true; } ]; };
  invalidAgent = self.nixosConfigurations.victus.extendModules {
    modules = [
      {
        fleet.lab.kubernetes = {
          enable = true;
          role = "agent";
        };
      }
    ];
  };
  rejected = node: lib.any (a: !a.assertion) node.config.assertions;
in
{
  fleet-policy =
    assert lib.all (name: builtins.elem name fleet.workstationNames) [
      "desktop"
      "thinkpad"
      "victus"
    ];
    assert builtins.elem "server-test" testFleet.serverNames;
    assert !(builtins.elem "server-test" testFleet.homeHostNames);
    assert !(builtins.hasAttr "${username}@server-test" testOutputs.homeConfigurations);
    assert builtins.elem "server-test" (endpointHosts "ssh");
    assert !(builtins.elem "server-test" (endpointHosts "syncthing"));
    assert !(builtins.elem "server-test" (endpointHosts "lan-mouse"));
    assert home.programs.ssh.settings.server-test.data.User == username;
    assert !(builtins.elem "server-test" testFleet.inputSharingHostNames);
    assert !c.services.xserver.enable && !c.programs.hyprland.enable;
    assert !c.services.displayManager.sddm.enable && !c.services.pipewire.enable;
    assert !c.hardware.bluetooth.enable && !c.virtualisation.docker.enable;
    assert !c.services.k3s.enable && !c.services.syncthing.enable;
    assert !(builtins.elem "docker" c.users.users.${username}.extraGroups);
    assert c.services.tailscale.enable && c.services.openssh.enable;
    assert
      c.services.tailscale.extraSetFlags == [
        "--hostname=server-test"
        "--shields-up=false"
        "--ssh"
      ];
    assert c.services.openssh.settings.PasswordAuthentication == false;
    assert c.services.openssh.settings.KbdInteractiveAuthentication == false;
    assert c.services.openssh.settings.PermitRootLogin == "no";
    assert !c.services.openssh.openFirewall;
    assert !(builtins.elem 22 c.networking.firewall.allowedTCPPorts);
    assert builtins.elem 22 c.networking.firewall.interfaces.tailscale0.allowedTCPPorts;
    assert !c.systemd.sleep.settings.Sleep.AllowSuspend;
    assert c.services.logind.settings.Login.HandleLidSwitch == "ignore";
    assert c.nix.settings.max-jobs == 1 && c.nix.settings.cores == 1;
    assert fleet.hosts.desktop.capabilities == fleet.hosts.victus.capabilities;
    assert !self.nixosConfigurations.victus.config.services.k3s.enable;
    assert k8s.config.services.k3s.enable && k8s.config.systemd.services.k3s.wantedBy == [ ];
    assert runner.config.systemd.services.lab-agent.wantedBy == [ ];
    assert runner.config.networking.firewall.interfaces.docker0.allowedTCPPorts == [ ];
    assert runner.config.networking.firewall.interfaces.docker0.allowedTCPPortRanges == [ ];
    assert rejected invalidK8s && rejected invalidAgent;
    pkgsFor.runCommand "fleet-policy-check" { } ''touch "$out"'';
  # Build, do not activate, a complete headless system using the same constructor.
  headless-system = c.system.build.toplevel;
}
