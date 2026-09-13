{ pkgs, ... }:

let
  mkPowerProfile =
    name: profile:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [ pkgs.power-profiles-daemon ];
      text = ''
        exec powerprofilesctl set ${profile}
      '';
    };
in
{
  home.packages = [
    (mkPowerProfile "work-balanced" "balanced")
    (mkPowerProfile "work-performance" "performance")
    (mkPowerProfile "work-save" "power-saver")
  ];
}
