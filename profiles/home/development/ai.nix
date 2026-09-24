{
  aiToolsPackages,
  herdrPackage,
  kiroPackages,
  ...
}:

{
  home.packages = [
    kiroPackages.cli
    herdrPackage
    aiToolsPackages.claude-code
    aiToolsPackages.codex
    aiToolsPackages.opencode
    aiToolsPackages.rtk
  ];
}
