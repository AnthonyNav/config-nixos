{
  lib,
  pkgs,
  aiToolsPackages,
  herdrPackage ? null,
  kiroPackages ? null,
  ...
}:

{
  imports = [
    ../../../modules/home/ai-environment.nix
  ];
  fleet.ai.enable = lib.mkDefault true;

  home.packages = [
    aiToolsPackages.claude-code
    aiToolsPackages.codex
    aiToolsPackages.rtk
  ]
  ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    kiroPackages.cli
    herdrPackage
  ];
}
