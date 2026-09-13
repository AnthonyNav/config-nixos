{ aiToolsPackages, pkgs, ... }:

{
  home.packages = [
    pkgs.kiro-cli
    aiToolsPackages.claude-code
    aiToolsPackages.codex
    aiToolsPackages.opencode
    aiToolsPackages.rtk
  ];
}
