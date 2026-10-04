{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "workstation-doctor";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.procps
        pkgs.systemd
        pkgs.hyprland
      ];
      text = builtins.readFile ../../scripts/workstation-doctor.sh;
    })
  ];
}
