{
  lib,
  aiToolsPackages,
  herdrPackage,
  kiroPackages,
  ...
}:

{
  imports = [ ../../../modules/home/ai-environment.nix ];
  fleet.ai.enable = lib.mkDefault true;

  home.packages = [
    kiroPackages.cli
    herdrPackage
    aiToolsPackages.claude-code
    aiToolsPackages.codex
    aiToolsPackages.opencode
    aiToolsPackages.rtk
  ];
}
