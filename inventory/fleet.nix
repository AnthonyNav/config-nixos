{
  hosts ? import ./hosts.nix,
}:
let
  namesWhere = predicate: builtins.filter (name: predicate hosts.${name}) (builtins.attrNames hosts);
  hostNames = builtins.attrNames hosts;
  workstationNames = namesWhere (host: host.kind == "workstation");
  serverNames = namesWhere (host: host.kind == "server");
  homeHostNames = namesWhere (host: host.homeModules != null);
  sshHostNames = namesWhere (host: host.connectivity.ssh or false);
  syncthingHostNames = namesWhere (host: host.connectivity.syncthing or false);
  inputSharingHostNames = namesWhere (host: host.features.inputSharing.enable or false);
  labHostNames = namesWhere (
    host:
    (host.features.virtualizationLab.enable or false)
    || (host.capabilities.kubernetes or false)
    || (host.capabilities.ci or false)
  );
  inventory = builtins.mapAttrs (
    _: host:
    (builtins.removeAttrs host [
      "systemModule"
      "homeModules"
    ])
    // {
      hasHome = host.homeModules != null;
    }
  ) hosts;
in
assert builtins.all (
  name:
  builtins.elem hosts.${name}.kind [
    "workstation"
    "server"
  ]
) hostNames;
assert builtins.all (
  name: hosts.${name}.kind == "workstation" && hosts.${name}.desktopStyle != null
) inputSharingHostNames;
assert builtins.all (name: hosts.${name}.desktopStyle == null) serverNames;
{
  inherit
    hosts
    inventory
    hostNames
    workstationNames
    serverNames
    homeHostNames
    sshHostNames
    syncthingHostNames
    inputSharingHostNames
    labHostNames
    ;
  buildMatrix = map (host: {
    inherit host;
    inherit (hosts.${host}) system;
    home = builtins.elem host homeHostNames;
  }) hostNames;
}
