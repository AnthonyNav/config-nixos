{ inputs, pkgs, ... }:

let
  # La CLI real de Caelestia (mismo paquete que usaría por default
  # programs.caelestia.cli.package, ver el flake de caelestia-shell:
  # cli-default = self.inputs.caelestia-cli.packages.${system}.default en su
  # nix/hm-module.nix). La resolvemos explícitamente para poder envolverla.
  realCli = inputs.caelestia-shell.inputs.caelestia-cli.packages.${pkgs.system}.default;

  # El switch claro/oscuro del panel de Caelestia (WallpaperAndStyle.qml ->
  # Colours.setMode() -> `caelestia scheme set --notify -m <mode>`, ver
  # services/Colours.qml en caelestia-shell) SOLO manda `--mode`, sin
  # `--flavour`/`--name`. Pero en Catppuccin, "mocha" únicamente tiene modo
  # dark y "latte" únicamente modo light: son flavours DISTINTOS, no una sola
  # paleta con ambos modos (ver data/schemes/catppuccin/{mocha,latte}/ en
  # caelestia-cli). Sin este wrapper, ese `-m light` truena con ValueError
  # ("does not have a light mode") antes de aplicar nada — ni el postHook
  # llega a correr. Como scheme_data_dir vive en el store de solo lectura, no
  # se puede "fusionar" ahí; la única salida es interceptar la llamada aquí.
  #
  # Este wrapper SOLO reescribe `caelestia scheme set` cuando trae `-m/--mode`
  # y NO trae ya `-f/--flavour` ni `-n/--name` (ese es exactamente el caso del
  # panel); le inyecta el flavour Catppuccin correcto para el modo pedido.
  # Cualquier otra invocación (incluida la que ya usa theme-sync.nix, que
  # siempre pasa --name/--flavour explícitos) pasa intacta al binario real.
  modeWrapper = pkgs.writeShellScript "caelestia-mode-wrapper" ''
    set -euo pipefail
    real="${realCli}/bin/caelestia"

    if [[ "''${1:-}" == "scheme" && "''${2:-}" == "set" ]]; then
      shift 2
      args=("$@")
      mode=""
      has_flavour=false
      has_name=false
      rest=()
      i=0
      while [[ $i -lt ''${#args[@]} ]]; do
        arg="''${args[$i]}"
        case "$arg" in
          -m|--mode)
            mode="''${args[$((i + 1))]}"
            rest+=("$arg" "$mode")
            i=$((i + 2))
            ;;
          --mode=*)
            mode="''${arg#*=}"
            rest+=("$arg")
            i=$((i + 1))
            ;;
          -f|--flavour)
            has_flavour=true
            rest+=("$arg" "''${args[$((i + 1))]}")
            i=$((i + 2))
            ;;
          --flavour=*)
            has_flavour=true
            rest+=("$arg")
            i=$((i + 1))
            ;;
          -n|--name)
            has_name=true
            rest+=("$arg" "''${args[$((i + 1))]}")
            i=$((i + 2))
            ;;
          --name=*)
            has_name=true
            rest+=("$arg")
            i=$((i + 1))
            ;;
          *)
            rest+=("$arg")
            i=$((i + 1))
            ;;
        esac
      done

      if [[ -n "$mode" && "$has_flavour" == false && "$has_name" == false ]]; then
        case "$mode" in
          light) rest+=("--name" "catppuccin" "--flavour" "latte") ;;
          dark) rest+=("--name" "catppuccin" "--flavour" "mocha") ;;
        esac
      fi

      exec "$real" scheme set "''${rest[@]}"
    fi

    exec "$real" "$@"
  '';

  # Reemplaza SOLO bin/caelestia por el wrapper; el resto del paquete
  # (completions de fish, etc.) sigue siendo el original vía symlinkJoin.
  wrappedCli = pkgs.symlinkJoin {
    name = "caelestia-cli-catppuccin-mode-wrapper";
    paths = [ realCli ];
    postBuild = ''
      rm "$out/bin/caelestia"
      ln -s ${modeWrapper} "$out/bin/caelestia"
    '';
  };

  # `programs.caelestia.cli.package` (abajo) sólo cambia qué `caelestia` se
  # instala en home.packages (el que usan una terminal nueva, el bind de
  # Hyprland, etc.) — el propio *binario del shell* NO lo usa. El paquete
  # `caelestia-shell` (variante "with-cli", ver flake.nix de caelestia-shell:
  # `with-cli = caelestia-shell.override { withCli = true; }`, usada como
  # default de `programs.caelestia.package`) se construye con
  # `makeWrapper ... --prefix PATH : "${lib.makeBinPath runtimeDeps}"`
  # (nix/default.nix), y `runtimeDeps` incluye la CLI **sin envolver**
  # (`caelestia-cli` tal cual la pasa el flake, antes de cualquier override
  # nuestro) porque así la compiló upstream. Ese `--prefix PATH` se antepone
  # al PATH heredado del proceso — así que el switch claro/oscuro del panel
  # (que corre `Quickshell.execDetached(["caelestia", ...])` DENTRO de ese
  # proceso) siempre encontraba la CLI real sin envolver primero, ignorando
  # nuestro wrapper del perfil general (confirmado: el PATH del proceso
  # `caelestia-shell` en vivo listaba la ruta de la CLI real ANTES que
  # `/etc/profiles/per-user/<user>/bin`). Por eso los comandos de terminal y
  # el atajo de Hyprland (que sí resuelven contra el PATH del perfil) ya
  # funcionaban, pero el switch del panel no.
  #
  # Fix: reconstruir la variante "with-cli" pasándole NUESTRA CLI envuelta en
  # el mismo argumento (`caelestia-cli`) que el flake usa para ese
  # runtimeDeps, en vez de tocar algo después de compilado.
  wrappedShell = inputs.caelestia-shell.packages.${pkgs.system}.caelestia-shell.override {
    withCli = true;
    caelestia-cli = wrappedCli;
  };
in
{
  # Sobreescribe tanto el binario del shell (para que execDetached del panel
  # use nuestro wrapper) como el paquete de la CLI que se instala aparte en
  # home.packages (terminal, Hyprland) — ver modules/home/caelestia.nix.
  programs.caelestia.package = wrappedShell;
  programs.caelestia.cli.package = wrappedCli;
}
