{ pkgs, ... }:

{
  # Explicit manual override. Stop automation only after validating arguments,
  # so a typo does not disable automation. `monitor-auto on` restores profiles.
  #
  # Real ejecutable vía home.packages (no función de zsh): mismo motivo
  # documentado para theme-* en theme-mode.nix — así puede invocarse también
  # desde un bind de Hyprland (exec corre por sh -c, no zsh; ver zsh.nix).
  home.packages = [
    (pkgs.writeShellApplication {
      name = "set-monitor";
      runtimeInputs = [
        pkgs.jq
        pkgs.hyprland
        pkgs.libnotify
        pkgs.coreutils
        pkgs.systemd
      ];
      text = builtins.readFile ../../scripts/set-monitor.sh;
    })
  ];
}
