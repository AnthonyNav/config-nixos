{
  dbgatePackage,
  kiroPackages,
  ...
}:

{
  home.packages = [
    kiroPackages.ide
    dbgatePackage
  ];

  imports = [
    ./mobile-development.nix
    ../development/data-science.nix
    ../creative-production.nix
    ../performance-workstation.nix
  ];
}
