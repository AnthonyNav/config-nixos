{ lib, pkgs, ... }:
let
  backend = pkgs.writeShellApplication {
    name = "fleet-ui-backend";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.python3
      pkgs.ffmpeg
    ];
    text = builtins.readFile ./fleet-ui-native.sh;
  };
  nativeShortcuts = pkgs.writeShellApplication {
    name = "fleet-shortcuts";
    runtimeInputs = [ backend ];
    text = ''exec fleet-ui-backend shortcuts "$@"'';
  };
in
{
  fleet.interaction.backend = backend;

  # The Mac uses native keyboard/window controls. Existing login registrations
  # are removed locally during migration; Home Manager retires the old files.
  # The shared catalogue still supplies the Linux guide.
  home.packages = [ (lib.hiPrio nativeShortcuts) ];
}
