{
  config,
  lib,
  pkgs,
  ...
}:
let
  tools = import ../../packages/workspace-tools.nix {
    inherit pkgs lib;
    inherit (config.home) homeDirectory;
  };
in
{
  programs.git.package = tools.git;
  programs.gh = {
    enable = true;
    package = tools.gh;
    gitCredentialHelper.enable = false;
  };
}
