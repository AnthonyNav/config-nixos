{ pkgs, source }:
pkgs.runCommand "fleet-interaction-check"
  {
    nativeBuildInputs = [
      pkgs.bash
      pkgs.shellcheck
      pkgs.python3
      pkgs.jq
      pkgs.lua
    ];
  }
  ''
    export PYTHONDONTWRITEBYTECODE=1
    shellcheck ${source}/scripts/fleet-{ui,ui-linux,ui-darwin,menu,shortcuts}.sh
    bash ${source}/scripts/fleet-ui-linux.sh --help >/dev/null
    bash ${source}/scripts/fleet-ui-darwin.sh --help >/dev/null
    ! grep -Eiq 'darwin|linux|hyprland|aerospace' ${source}/scripts/fleet-ui.sh
    python ${source}/scripts/tests/check-fleet-interaction.py ${source}
    python ${source}/scripts/tests/check-fleet-media.py ${source}/scripts/fleet-media.py
    python ${source}/scripts/tests/check-fleet-darwin.py ${source} ${pkgs.lua}/bin/lua
    touch "$out"
  ''
