{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  cfg = config.fleet.backup;
  runtimePath =
    value:
    lib.hasPrefix "/" value
    && !(lib.hasPrefix "/nix/store/" value)
    && !(lib.hasPrefix "${config.users.users.${username}.home}/nixos-config/" value);
  common = {
    inherit (cfg) repositoryFile passwordFile environmentFile;
    user = username;
    initialize = false;
  };
in
{
  options.fleet.backup = {
    enable = lib.mkEnableOption "encrypted personal Restic backups";
    paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Explicit absolute personal data paths to back up.";
    };
    repositoryFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/fleet-backup/repository";
      description = "Local file containing the Restic destination, outside Git and the store.";
    };
    passwordFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/fleet-backup/password";
      description = "Local repository password file; keep its recovery copy separately.";
    };
    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional local file with remote backup credentials.";
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.paths != [ ] && lib.all (lib.hasPrefix "/") cfg.paths;
        message = "fleet.backup requires explicit absolute data paths.";
      }
      {
        assertion = lib.all runtimePath (
          [
            cfg.repositoryFile
            cfg.passwordFile
          ]
          ++ lib.optional (cfg.environmentFile != null) cfg.environmentFile
        );
        message = "Backup credentials and destination files must be runtime paths outside Git and /nix/store.";
      }
    ];
    # No automatic initialisation: verify the intended disk/repository first.
    services.restic.backups = {
      fleet-personal = common // {
        inherit (cfg) paths;
        createWrapper = true;
        exclude = [
          "**/.cache"
          "**/node_modules"
          "**/.direnv"
        ];
        pruneOpts = [
          "--keep-daily 7"
          "--keep-weekly 4"
          "--keep-monthly 6"
        ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
      };
      fleet-integrity = common // {
        checkOpts = [ "--read-data-subset=5%" ];
        timerConfig = {
          OnCalendar = "weekly";
          Persistent = true;
          RandomizedDelaySec = "2h";
        };
      };
    };
    systemd.tmpfiles.rules = [ "d /var/lib/fleet-backup 0700 ${username} users -" ];
    systemd.services =
      lib.genAttrs [ "restic-backups-fleet-personal" "restic-backups-fleet-integrity" ]
        (_: {
          serviceConfig = {
            Nice = 10;
            IOSchedulingClass = "idle";
            CPUWeight = 25;
            IOWeight = 25;
          };
        });
    environment.systemPackages = [ pkgs.restic ];
  };
}
