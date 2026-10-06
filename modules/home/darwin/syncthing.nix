{
  config,
  lib,
  pkgs,
  fleetInventory,
  hostFeatures,
  ...
}:
let
  enabled = hostFeatures.connectivity.syncthing or false;
  syncthing = import ../../../packages/syncthing-fleet.nix {
    inherit pkgs lib fleetInventory;
    inherit (config.home) homeDirectory;
    inherit (hostFeatures) hostName;
    configDirectory = "${config.home.homeDirectory}/Library/Application Support/Syncthing";
  };
in
{
  assertions = lib.optionals enabled syncthing.assertions;
  services.syncthing = lib.mkIf enabled {
    enable = true;
    overrideDevices = false;
    overrideFolders = false;
    # Syncthing 2 creates no default folder and rejects the former CLI flag.
    inherit (syncthing) settings;
  };
  home.packages = lib.optionals enabled [
    pkgs.syncthing
    syncthing.reconcile
  ];
  home.activation.syncthingLogs = lib.mkIf enabled (
    lib.hm.dag.entryBetween [ "setupLaunchAgents" ] [ "writeBoundary" ] ''
      run ${pkgs.coreutils}/bin/install -d -m 0700 ${lib.escapeShellArg "${config.home.homeDirectory}/Library/Logs/Syncthing"}
    ''
  );
  launchd.agents.syncthing-fleet-reconcile = lib.mkIf enabled {
    enable = true;
    config = {
      ProgramArguments = [ (lib.getExe syncthing.reconcile) ];
      RunAtLoad = true;
      StartInterval = 600;
      ProcessType = "Background";
      EnvironmentVariables.HOME = config.home.homeDirectory;
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/Syncthing/fleet-stdout.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/Syncthing/fleet-stderr.log";
    };
  };
}
