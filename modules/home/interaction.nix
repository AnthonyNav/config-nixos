{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.fleet.interaction;

  fleetMenu = pkgs.writeShellApplication {
    name = "fleet-menu";
    runtimeInputs = [ pkgs.fzf ];
    text = builtins.readFile ../../scripts/fleet-menu.sh;
  };

  fleetShortcuts = pkgs.writeShellApplication {
    name = "fleet-shortcuts";
    text = builtins.readFile ../../scripts/fleet-shortcuts.sh;
  };

  fleetUi = pkgs.writeShellApplication {
    name = "fleet-ui";
    runtimeInputs = [
      cfg.backend
      fleetMenu
      fleetShortcuts
    ];
    text = builtins.readFile ../../scripts/fleet-ui.sh;
  };
in
{
  options.fleet.interaction.backend = lib.mkOption {
    type = lib.types.package;
    description = "Platform adapter implementing the portable Fleet interaction contract.";
  };

  # Shared human-interface contract. Platform modules provide the backend;
  # this module contains no Linux or Darwin implementation details.
  home.packages = [
    fleetUi
    fleetMenu
    fleetShortcuts
  ];
}
