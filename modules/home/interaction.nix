{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.fleet.interaction;
  catalogue = pkgs.writeText "fleet-actions.json" (
    builtins.readFile ../../dotfiles/fleet/actions.json
  );
  fleetCatalog = pkgs.writeShellApplication {
    name = "fleet-catalog";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${../../scripts/fleet-catalog.py} --catalog ${catalogue} "$@"
    '';
  };
  fleetMedia = pkgs.writeShellApplication {
    name = "fleet-media";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${../../scripts/fleet-media.py} "$@"
    '';
  };

  fleetMenu = pkgs.writeShellApplication {
    name = "fleet-menu";
    text = builtins.readFile ../../scripts/fleet-menu.sh;
  };

  fleetShortcuts = pkgs.writeShellApplication {
    name = "fleet-shortcuts";
    runtimeInputs = [ fleetCatalog ];
    text = builtins.readFile ../../scripts/fleet-shortcuts.sh;
  };

  fleetUi = pkgs.writeShellApplication {
    name = "fleet-ui";
    runtimeInputs = [
      cfg.backend
      fleetMenu
      fleetShortcuts
      fleetCatalog
      fleetMedia
    ];
    text = builtins.readFile ../../scripts/fleet-ui.sh;
  };
in
{
  imports = [ ./fleet-editor-bindings.nix ];

  options.fleet.interaction.backend = lib.mkOption {
    type = lib.types.package;
    description = "Platform adapter implementing the portable Fleet interaction contract.";
  };

  # Shared human-interface contract. Platform modules provide the backend;
  # this module contains no Linux or Darwin implementation details.
  config = {
    home.packages = [ fleetUi fleetMenu fleetShortcuts fleetCatalog fleetMedia ];
    xdg.configFile."fleet/actions.json".source = catalogue;
  };
}
