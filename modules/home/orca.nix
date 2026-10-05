{
  config,
  hostFeatures,
  lib,
  pkgs,
  ...
}:
let
  orca = pkgs.callPackage ../../packages/orca-ide.nix { };
  workspaceTools = import ../../packages/workspace-tools.nix {
    inherit pkgs lib;
    inherit (config.home) homeDirectory;
  };
  headlessGui = pkgs.writeShellScript "orca-headless-profile-owner" ''
    printf '%s\n' 'This Orca profile is owned by orca-serve.service. Connect from a paired client; change the reviewed host mode before using its GUI.' >&2
    exit 3
  '';
  launcher = pkgs.symlinkJoin {
    name = "fleet-orca-${orca.version}";
    inherit (orca) version meta;
    paths = [ orca ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/orca-ide" --prefix PATH : ${workspaceTools.wrappers}/bin
      ${
        if (hostFeatures.orcaRemote.mode or "off") == "headless" then
          ''ln -sf ${headlessGui} "$out/bin/orca-ide-gui"''
        else
          ''wrapProgram "$out/bin/orca-ide-gui" --prefix PATH : ${workspaceTools.wrappers}/bin''
      }
      # symlinkJoin shares the original desktop file; copy before modifying it.
      desktop="$out/share/applications/orca-ide.desktop"
      cp --remove-destination "$desktop" "$desktop.tmp"
      mv "$desktop.tmp" "$desktop"
      substituteInPlace "$desktop" \
        --replace-fail '${orca}/bin/orca-ide-gui' "$out/bin/orca-ide-gui"
    '';
  };
  skills = pkgs.writeShellApplication {
    name = "orca-skills-sync";
    text = ''exec ${pkgs.python3}/bin/python3 -B ${../../scripts/orca-skills-sync.py} --binary ${launcher}/bin/orca-ide "$@"'';
  };
in
{
  options.fleet.ai.orca.enable = lib.mkEnableOption "the optional Orca desktop application";

  config.home.packages = lib.optionals config.fleet.ai.orca.enable [
    launcher
    skills
  ];
}
