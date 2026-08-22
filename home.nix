{ ... }:

{
  imports = [
    ./profiles/home/base.nix
    ./profiles/home/identities.nix
    ./profiles/home/fleet-access.nix
    ./profiles/home/development.nix
    ./profiles/home/database-tools.nix
  ];
}
