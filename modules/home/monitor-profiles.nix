{
  config,
  lib,
  pkgs,
  ...
}:
let
  policy = pkgs.writeText "monitor-policy.json" (
    builtins.toJSON (import ../../inventory/displays.nix)
  );
  layout = pkgs.writeShellApplication {
    name = "monitor-layout";
    runtimeInputs = [
      pkgs.hyprland
      pkgs.python3
    ];
    text = ''exec python3 ${../../scripts/monitor-layout.py} --policy ${policy} "$@"'';
  };
  auto = pkgs.writeShellApplication {
    name = "monitor-auto";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      case "''${1:-status}" in
        on) systemctl --user restart monitor-layout.service ;;
        off) systemctl --user stop monitor-layout.service ;;
        status) systemctl --user --no-pager status monitor-layout.service ;;
        *) echo "Usage: monitor-auto [on|off|status]" >&2; exit 64 ;;
      esac
    '';
  };
in
{
  systemd.user.services.monitor-layout = {
    Unit = {
      Description = "Event-driven, hardware-independent Hyprland monitor profiles";
      PartOf = [ config.wayland.systemd.target ];
      After = [ config.wayland.systemd.target ];
      ConditionEnvironment = "HYPRLAND_INSTANCE_SIGNATURE";
    };
    Service = {
      ExecStart = "${lib.getExe layout} --watch";
      Restart = "always";
      RestartSec = 3;
    };
    Install.WantedBy = [ config.wayland.systemd.target ];
  };
  home.packages = [
    auto
    layout
  ];
}
