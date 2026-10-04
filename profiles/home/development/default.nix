{ dbgatePackage, kiroPackages, ... }:
{
  imports = [
    ./base.nix
    ./flutter.nix
    ./web-backend.nix
    ./api-database.nix
    ./spec-kit.nix
  ];
  home.packages = [
    kiroPackages.ide
    dbgatePackage
  ];
}
