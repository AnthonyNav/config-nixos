{ lib, pkgs }:
let
  evaluate =
    settings:
    (lib.evalModules {
      modules = [
        ../profiles/home/development/web-backend.nix
        ../modules/home/project-environments.nix
        {
          config._module.args.pkgs = pkgs;
          options.home.packages = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ ];
          };
          options.programs.zsh.initContent = lib.mkOption {
            type = lib.types.lines;
            default = "";
          };
          config.fleet.development = settings;
        }
      ];
    }).config;
  legacy = evaluate { legacyJupyterLibraries = true; };
  isolated = evaluate {
    globalToolchains = {
      node = false;
      go = false;
      c = false;
      python = false;
    };
    legacyJupyterLibraries = false;
  };
  noGo = evaluate { globalToolchains.go = false; };
  names = c: map lib.getName c.home.packages;
in
{
  project-environments =
    assert
      names legacy == map lib.getName [
        pkgs.nodejs_22
        pkgs.go
        pkgs.gotestsum
        pkgs.mockgen
        (lib.hiPrio pkgs.gcc)
        pkgs.python3
        pkgs.uv
      ];
    assert names isolated == [ (lib.getName pkgs.uv) ];
    assert isolated.programs.zsh.initContent == "";
    assert !(builtins.elem (lib.getName pkgs.go) (names noGo));
    assert builtins.elem (lib.getName pkgs.nodejs_22) (names noGo);
    pkgs.runCommand "project-environments-check" { } ''
      ${pkgs.zsh}/bin/zsh -f ${pkgs.writeText "project-environments-test.zsh" ''
        set -eu
        export LD_LIBRARY_PATH=/test/existing
        source ${pkgs.writeText "legacy-jupyter.zsh" legacy.programs.zsh.initContent}
        expected="${
          lib.makeLibraryPath [
            pkgs.stdenv.cc.cc.lib
            pkgs.zlib
            pkgs.expat
          ]
        }:/test/existing"
        [[ "$LD_LIBRARY_PATH" == "$expected" ]]
        source ${pkgs.writeText "legacy-jupyter.zsh" legacy.programs.zsh.initContent}
        [[ "$LD_LIBRARY_PATH" == "$expected" ]]
        unset LD_LIBRARY_PATH
        source ${pkgs.writeText "isolated-project.zsh" isolated.programs.zsh.initContent}
        [[ ! -v LD_LIBRARY_PATH ]]
      ''}
      touch "$out"
    '';
}
