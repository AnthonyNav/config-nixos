{
  config,
  lib,
  pkgs,
  ...
}:
let
  tools = import ../../packages/workspace-tools.nix {
    inherit pkgs lib;
    inherit (config.home) homeDirectory;
  };
  command = "${tools.wrappers}/bin/workspace-sync";
  darwin = pkgs.stdenv.hostPlatform.isDarwin;
in
{
  # The private registry starts empty. Each checkout must be registered by its
  # owner; installing the timer alone never enrolls a repository.
  systemd.user.services.workspace-sync = lib.mkIf (!darwin) {
    Unit.Description = "Receive published changes in registered idle Git checkouts";
    Service = {
      Type = "oneshot";
      ExecStart = "${command} run --json";
      WorkingDirectory = config.home.homeDirectory;
      Environment = [ "HOME=${config.home.homeDirectory}" ];
      UMask = "0077";
      Nice = 10;
    };
  };
  systemd.user.timers.workspace-sync = lib.mkIf (!darwin) {
    Unit.Description = "Periodically receive registered Git branches";
    Timer = {
      OnStartupSec = "30s";
      OnUnitInactiveSec = "2m";
      Unit = "workspace-sync.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
  home.activation.workspaceSyncLogs = lib.mkIf darwin (
    lib.hm.dag.entryBetween [ "setupLaunchAgents" ] [ "writeBoundary" ] ''
      run ${pkgs.coreutils}/bin/install -d -m 0700 ${lib.escapeShellArg "${config.home.homeDirectory}/Library/Logs/Fleet"}
    ''
  );
  launchd.agents.workspace-sync = lib.mkIf darwin {
    enable = true;
    config = {
      ProgramArguments = [
        command
        "run"
        "--json"
      ];
      RunAtLoad = true;
      StartInterval = 120;
      ProcessType = "Background";
      EnvironmentVariables.HOME = config.home.homeDirectory;
      Umask = 63;
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/Fleet/workspace-sync.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/Fleet/workspace-sync-error.log";
    };
  };
}
