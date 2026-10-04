{ ... }:

{
  imports = [
    ../../profiles/home/roles/creative-ml-development.nix
    ../../modules/home/monitors-desktop.nix
  ];

  fleet.ai.orca.enable = true;
}
