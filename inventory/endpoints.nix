{
  fleet ? import ./fleet.nix { },
}:
let
  inherit (fleet) workstationNames;
  ports = {
    ssh = 22;
    syncthing = 22000;
    lanMouse = 4242;
    orca = 6768;
  };
in
{
  inherit ports workstationNames;

  # These declarations are the source of truth for tailnet grants. Modules
  # still own their corresponding per-interface firewall rules.
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
  ]
  ++ (
    if fleet.orcaRemoteHostNames == [ ] then
      [ ]
    else
      [
        {
          name = "orca";
          protocol = "tcp";
          port = ports.orca;
          hosts = fleet.orcaRemoteHostNames;
        }
      ]
  );

  public = [ ];
}
