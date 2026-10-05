{
  hosts ? import ./hosts.nix,
}:
let
  namesWhere = predicate: builtins.filter (name: predicate hosts.${name}) (builtins.attrNames hosts);
  hostNames = builtins.attrNames hosts;
  workstationNames = namesWhere (host: host.kind == "workstation");
  homeHostNames = hostNames;
  sshHostNames = namesWhere (host: host.connectivity.ssh or false);
  syncthingHostNames = namesWhere (host: host.connectivity.syncthing or false);
  inputSharingHostNames = namesWhere (host: host.features.inputSharing.enable or false);
  orcaRemoteHostNames = namesWhere (host: (host.features.orcaRemote.mode or "off") == "desktop-app");
  inventory = builtins.mapAttrs (
    _: host:
    (builtins.removeAttrs host [
      "systemModule"
      "homeModules"
    ])
    // {
      hasHome = true;
    }
  ) hosts;
in
assert builtins.all (
  name: hosts.${name}.kind == "workstation" && hosts.${name}.homeModules != null
) hostNames;
assert builtins.all (
  name: hosts.${name}.kind == "workstation" && hosts.${name}.desktopStyle != null
) inputSharingHostNames;
assert builtins.all (name: hosts.${name}.desktopStyle != null) hostNames;
{
  inherit
    hosts
    inventory
    hostNames
    workstationNames
    homeHostNames
    sshHostNames
    syncthingHostNames
    inputSharingHostNames
    orcaRemoteHostNames
    ;
  buildMatrix = map (host: {
    inherit host;
    inherit (hosts.${host}) system;
    home = builtins.elem host homeHostNames;
  }) hostNames;
}
