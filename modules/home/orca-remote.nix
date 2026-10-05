{
  config,
  hostFeatures,
  lib,
  pkgs,
  ...
}:
let
  enabled = (hostFeatures.orcaRemote.mode or "off") == "headless";
  orca = pkgs.callPackage ../../packages/orca-ide.nix { };
  port = (import ../../inventory/endpoints.nix { }).ports.orca;
  workspaceTools = import ../../packages/workspace-tools.nix {
    inherit pkgs lib;
    inherit (config.home) homeDirectory;
  };
  serve = pkgs.writeShellApplication {
    name = "orca-serve-fleet";
    runtimeInputs = [
      pkgs.tailscale
      pkgs.jq
      pkgs.coreutils
      pkgs.iproute2
      pkgs.systemd
      pkgs.xorg-server
    ];
    text = builtins.readFile ../../scripts/orca-serve-fleet.sh;
  };
  command =
    action:
    lib.escapeShellArgs [
      "${pkgs.python3}/bin/python3"
      "-B"
      "${../../scripts}/orca-server.py"
      action
      "--home"
      config.home.homeDirectory
      "--port"
      (toString port)
      "--orca"
      "${orca}/bin/orca-ide"
    ];
  helpers =
    map
      (
        action:
        pkgs.writeShellApplication {
          name = "orca-server-${action}";
          runtimeInputs = [
            pkgs.systemd
            pkgs.tailscale
            pkgs.iproute2
            pkgs.xorg-server
          ];
          text = ''exec ${command action} "$@"'';
        }
      )
      [
        "status"
        "logs"
        "restart"
      ];
in
{
  config = lib.mkIf enabled {
    assertions = [
      {
        assertion = config.fleet.ai.orca.enable;
        message = "Headless Orca needs the managed Orca package and workspace adapters.";
      }
    ];
    home.packages = helpers ++ [
      serve
      # Xwayland owns overlapping Xserver manuals in the daily profile.
      (lib.lowPrio pkgs.xorg-server)
    ];
    systemd.user.services.orca-serve = {
      Unit = {
        Description = "Fleet Orca Remote Runtime";
        StartLimitIntervalSec = 300;
        StartLimitBurst = 5;
      };
      Service = {
        Type = "simple";
        ExecStart = "${serve}/bin/orca-serve-fleet ${orca}/bin/orca-ide ${toString port}";
        WorkingDirectory = config.home.homeDirectory;
        Environment = [
          "HOME=${config.home.homeDirectory}"
          "PATH=${workspaceTools.wrappers}/bin:${config.home.path}/bin:/run/current-system/sw/bin"
          "LIBGL_ALWAYS_SOFTWARE=1"
          "XDG_RUNTIME_DIR=%t"
          "DBUS_SESSION_BUS_ADDRESS=unix:path=%t/bus"
        ];
        Restart = "on-failure";
        RestartSec = 5;
        RestartPreventExitStatus = 3;
        KillMode = "mixed";
        TimeoutStopSec = 45;
        UMask = "0077";
        StandardOutput = "journal";
        StandardError = "journal";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
