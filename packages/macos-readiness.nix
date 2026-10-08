{
  pkgs,
  lib ? pkgs.lib,
  hostName,
  username,
  homeDirectory,
}:
# Read-only: also usable before the first nix-darwin activation.
pkgs.writeShellApplication {
  name = "fleet-macos-readiness";
  runtimeInputs = with pkgs; [
    coreutils
    git
    nix
  ];
  text = ''
    export FLEET_EXPECTED_HOST=${lib.escapeShellArg hostName}
    export FLEET_EXPECTED_USER=${lib.escapeShellArg username}
    export FLEET_EXPECTED_HOME=${lib.escapeShellArg homeDirectory}
    ${builtins.readFile ../scripts/macos-readiness.sh}
  '';
}
