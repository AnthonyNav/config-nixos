{
  lib,
  pkgs,
  ...
}:
let
  fleetUi = pkgs.writeShellApplication {
    name = "fleet-ui";
    runtimeInputs = [
      pkgs.coreutils
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      pkgs.hyprland
    ];
    text = builtins.readFile ../../scripts/fleet-ui.sh;
  };

  fleetMenu = pkgs.writeShellApplication {
    name = "fleet-menu";
    runtimeInputs = [
      pkgs.fzf
      fleetUi
    ];
    text = builtins.readFile ../../scripts/fleet-menu.sh;
  };

  fleetShortcuts = pkgs.writeShellApplication {
    name = "fleet-shortcuts";
    text = builtins.readFile ../../scripts/fleet-shortcuts.sh;
  };
in
{
  # Shared human-interface contract. Platform adapters translate the same
  # actions to Hyprland/Caelestia or macOS/AeroSpace without leaking either
  # implementation into portable Home configuration.
  home.packages = [
    fleetUi
    fleetMenu
    fleetShortcuts
  ];
}
