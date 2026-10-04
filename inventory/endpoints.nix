{
  fleet ? import ./fleet.nix { },
}:
let
  inherit (fleet) workstationNames;
  ports = {
    ssh = 22;
    syncthing = 22000;
    lanMouse = 4242;
  };
in
{
  inherit ports workstationNames;

  remoteWorkspace = {
    backend = {
      hostname = "127.0.0.1";
      port = 8082;
    };
    # No workstation currently publishes a persistent web terminal.
    hosts = { };
    configFile = ".config/remote-workspace/zellij.kdl";
  };

  # These declarations are the source of truth for tailnet grants. Modules
  # still own their corresponding firewall and Tailscale Serve/Funnel units.
  tailnet = [
    {
      name = "ssh";
      protocol = "tcp";
      port = ports.ssh;
      hosts = fleet.sshHostNames;
    }
    {
      name = "syncthing";
      protocol = "tcp";
      port = ports.syncthing;
      hosts = fleet.syncthingHostNames;
    }
    {
      name = "lan-mouse";
      protocol = "udp";
      port = ports.lanMouse;
      hosts = fleet.inputSharingHostNames;
    }
  ];

  public = [ ];
}
