{
  config,
  lib,
  pkgs,
  ...
}:
let
  workspaceTools = import ../../../packages/workspace-tools.nix {
    inherit pkgs lib;
    inherit (config.home) homeDirectory;
  };
  # The native application owns its CLI. Register `orca` through its Settings
  # page; the compatibility entry point keeps shared workspace commands stable.
  launcher = pkgs.writeShellApplication {
    name = "orca-ide";
    text = ''
      export PATH=${workspaceTools.wrappers}/bin:"$PATH"
      command -v orca >/dev/null || {
        printf 'Install the native Orca app and register its CLI in Settings → General → Orca CLI.\n' >&2
        exit 69
      }
      exec orca "$@"
    '';
  };
  skills = pkgs.writeShellApplication {
    name = "orca-skills-sync";
    text = ''exec ${pkgs.python3}/bin/python3 -B ${../../../scripts/orca-skills-sync.py} --binary ${launcher}/bin/orca-ide "$@"'';
  };
in
{
  options.fleet.ai.orca.enable =
    lib.mkEnableOption "native Orca workflow helpers (application owned by Homebrew)";
  config = {
    fleet.ai.orca.enable = lib.mkDefault true;
    home.packages = lib.optionals config.fleet.ai.orca.enable [
      launcher
      skills
    ];
  };
}
