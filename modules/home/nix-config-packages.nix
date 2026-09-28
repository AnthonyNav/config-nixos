{
  lib,
  pkgs,
  username,
  fleetNames,
  homeHostNames,
}:

let
  nixConfig = pkgs.writeShellApplication {
    name = "nix-config";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.git
      pkgs.nix
      pkgs.systemd
    ];
    text = ''
      export NIX_CONFIG_USER=${lib.escapeShellArg username}
      export NIX_CONFIG_HOSTS=${lib.escapeShellArg (lib.concatStringsSep " " fleetNames)}
      export NIX_CONFIG_HOME_HOSTS=${lib.escapeShellArg (lib.concatStringsSep " " homeHostNames)}
      ${builtins.readFile ../../scripts/nix-config.sh}
    '';
  };

  mkCommand =
    {
      name,
      arguments,
      warning ? null,
    }:
    pkgs.writeShellApplication {
      inherit name;
      text = ''
        ${lib.optionalString (warning != null) ''printf '%s\n' ${lib.escapeShellArg warning} >&2''}
        exec ${lib.getExe nixConfig} ${lib.escapeShellArgs arguments} "$@"
      '';
    };

  nixSwitch = mkCommand {
    name = "nix-switch";
    arguments = [
      "switch"
      "system"
    ];
  };
  nixHomeSwitch = mkCommand {
    name = "nix-home-switch";
    arguments = [
      "switch"
      "home"
    ];
  };
  nixUpdate = mkCommand {
    name = "nix-update";
    arguments = [ "deploy" ];
  };
  nixCheck = mkCommand {
    name = "nix-check";
    arguments = [ "check" ];
  };
  nixStatus = mkCommand {
    name = "nix-status";
    arguments = [ "status" ];
  };
  nixFormat = mkCommand {
    name = "nix-format";
    arguments = [ "fmt" ];
  };
  nixGenerations = mkCommand {
    name = "nix-generations";
    arguments = [ "generations" ];
  };
  nixRollback = mkCommand {
    name = "nix-rollback";
    arguments = [
      "rollback"
      "system"
    ];
  };
  nixClean = mkCommand {
    name = "nix-clean";
    arguments = [ "gc" ];
  };
  nixInputUpdate = mkCommand {
    name = "nix-input-update";
    arguments = [
      "inputs"
      "update"
    ];
  };
  hmSwitch = mkCommand {
    name = "hm-switch";
    arguments = [
      "switch"
      "home"
    ];
    warning = "hm-switch is deprecated; use nix-home-switch or nix-config switch home.";
  };
  nixosUpdate = mkCommand {
    name = "nixos-update";
    arguments = [ "deploy" ];
    warning = "nixos-update is deprecated; use nix-update or nix-config deploy.";
  };
in
{
  inherit
    hmSwitch
    nixCheck
    nixClean
    nixConfig
    nixFormat
    nixGenerations
    nixHomeSwitch
    nixInputUpdate
    nixRollback
    nixStatus
    nixSwitch
    nixUpdate
    nixosUpdate
    ;
}
