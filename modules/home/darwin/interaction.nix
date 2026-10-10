{ pkgs, ... }:
let
  backend = pkgs.writeShellApplication {
    name = "fleet-ui-backend";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.python3
      pkgs.ffmpeg
    ];
    text = builtins.readFile ../../../scripts/fleet-ui-darwin.sh;
  };
in
{
  fleet.interaction.backend = backend;

  # Fleet owns its Hammerspoon module, not Karabiner's mutable user profile.
  # Caps Lock keeps its native function; the menu uses an inspected app shortcut.
  home.file.".hammerspoon/fleet.lua".source = ../../../dotfiles/hammerspoon/fleet.lua;
  home.file.".hammerspoon/init.lua".text = ''
    hs.autoLaunch(true)
    fleetInteraction = require("fleet")
  '';

  # AeroSpace supplies the keyboard-oriented window/workspace backend. No
  # appearance, gaps, wallpaper, borders or other visual preferences are owned
  # here.
  home.file.".aerospace.toml".text = ''
    config-version = 2
    start-at-login = true
    auto-reload-config = true
    enable-normalization-flatten-containers = true
    enable-normalization-opposite-orientation-for-nested-containers = true
    default-root-container-layout = 'tiles'
    default-root-container-orientation = 'auto'

    [mode.main.binding]
  '';
}
