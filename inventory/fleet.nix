{
  hosts ? import ./hosts.nix,
  username ? "anthony",
}:
let
  namesWhere = predicate: builtins.filter (name: predicate hosts.${name}) (builtins.attrNames hosts);
  hostNames = builtins.attrNames hosts;
  workstationNames = namesWhere (host: host.kind == "workstation");
  nixosHostNames = namesWhere (host: host.platform == "nixos");
  darwinHostNames = namesWhere (host: host.platform == "darwin");
  homeHostNames = hostNames;
  sshHostNames = namesWhere (host: host.connectivity.ssh or false);
  syncthingHostNames = namesWhere (host: host.connectivity.syncthing or false);
  inputSharingHostNames = namesWhere (host: host.features.inputSharing.enable or false);
  orcaRemoteHostNames = namesWhere (host: (host.features.orcaRemote.mode or "off") != "off");
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
assert builtins.all (
  name:
  builtins.elem hosts.${name}.platform [
    "nixos"
    "darwin"
  ]
) hostNames;
assert builtins.all (
  name: builtins.match ".*-linux" hosts.${name}.system != null && hosts.${name}.desktopStyle != null
) nixosHostNames;
assert builtins.all (
  name: hosts.${name}.system == "aarch64-darwin" && hosts.${name}.desktopStyle == null
) darwinHostNames;
assert builtins.all (
  name:
  builtins.elem (hosts.${name}.features.orcaRemote.mode or "off") [
    "off"
    "desktop-app"
    "headless"
  ]
  && (
    (hosts.${name}.features.orcaRemote.mode or "off") != "headless" || hosts.${name}.platform == "nixos"
  )
) hostNames;
{
  inherit
    hosts
    inventory
    hostNames
    workstationNames
    nixosHostNames
    darwinHostNames
    homeHostNames
    sshHostNames
    syncthingHostNames
    inputSharingHostNames
    orcaRemoteHostNames
    ;
  buildMatrix = map (host: {
    inherit host;
    inherit (hosts.${host}) system platform;
    home = builtins.elem host homeHostNames;
    username = hosts.${host}.username or username;
  }) hostNames;
}
