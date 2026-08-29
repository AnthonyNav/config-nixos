{ ... }:

{
  # This host runs K3s and CI workloads, so it must remain reachable while idle.
  estoma.idle.suspendTimeoutSeconds = null;

  imports = [
    ../../modules/home/creative-suite.nix
    ../../modules/home/monitors-desktop.nix
  ];
}
