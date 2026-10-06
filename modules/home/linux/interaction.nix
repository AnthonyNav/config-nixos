{ pkgs, ... }:
let
  backend = pkgs.writeShellApplication {
    name = "fleet-ui-backend";
    runtimeInputs = [ pkgs.coreutils ];
    text = builtins.readFile ../../../scripts/fleet-ui-linux.sh;
  };
in
{
  fleet.interaction.backend = backend;
}
