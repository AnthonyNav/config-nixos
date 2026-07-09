{ pkgs, ... }:

{
  # `set-wallpaper`, `theme-light`, `theme-dark`, `theme-toggle`: ejecutables
  # reales instalados vía home.packages (NO funciones de zsh, ver el
  # comentario en zsh.nix) — porque también se disparan desde el atajo de
  # Hyprland (Super+Shift+T, hyprland.nix), y `exec` de Hyprland corre el
  # comando vía `sh -c`, no zsh: una función de zsh ahí no existiría (mismo
  # bug ya documentado para rofi/.desktop en gpu-launchers.nix).
  home.packages = [
    # Relanza mpvpaper con el gif que corresponde al modo (claro/oscuro)
    # actualmente activo en Caelestia. Se usa desde dos sitios, para que haya
    # una sola fuente de verdad:
    #   - hyprland.nix (exec-once), al iniciar sesión: respeta el modo
    #     persistido en scheme.json en vez de asumir siempre oscuro.
    #   - modules/home/caelestia.nix (theme.postHook), en caliente cada vez
    #     que cambias de modo (comando, atajo o el switch del panel de
    #     Caelestia).
    (pkgs.writeShellApplication {
      name = "set-wallpaper";
      runtimeInputs = [ pkgs.jq pkgs.procps pkgs.mpvpaper pkgs.coreutils ];
      text = ''
        state_file="$HOME/.local/state/caelestia/scheme.json"
        wallpapers_dir="$HOME/Pictures/Wallpapers"

        mode="dark"
        if [ -f "$state_file" ]; then
          mode="$(jq -r '.mode // "dark"' "$state_file" 2>/dev/null || echo dark)"
        fi

        if [ "$mode" = "light" ]; then
          wall="$wallpapers_dir/fondo-light.gif"
        else
          wall="$wallpapers_dir/fondo.gif"
        fi

        # Si el gif del modo activo todavía no existe (p.ej. primera
        # activación, antes de que wallpapers.nix termine de descargarlo), no
        # tumbamos el fondo que ya esté corriendo.
        if [ ! -f "$wall" ]; then
          exit 0
        fi

        pkill -x mpvpaper 2>/dev/null || true

        # nohup + redirección completa: este script puede ser invocado desde
        # el postHook de Caelestia (subprocess.run bloqueante de Python), así
        # que mpvpaper debe quedar totalmente desligado del proceso padre.
        nohup mpvpaper -o "no-audio --loop --keepaspect=no --vf=scale=1920:1080" \
          eDP-1 "$wall" >/dev/null 2>&1 &
      '';
    })

    # Van por el interceptor de modules/home/caelestia-scheme.nix: un
    # `caelestia scheme set -m <modo>` sin --flavour/--name se traduce solo a
    # Catppuccin mocha (dark) o latte (light). El postHook (caelestia.nix) ya
    # se encarga de kitty + GTK3 + fondo — no hace falta nada más aquí.
    (pkgs.writeShellApplication {
      name = "theme-light";
      text = ''caelestia scheme set --notify -m light'';
    })

    (pkgs.writeShellApplication {
      name = "theme-dark";
      text = ''caelestia scheme set --notify -m dark'';
    })

    (pkgs.writeShellApplication {
      name = "theme-toggle";
      runtimeInputs = [ pkgs.jq ];
      text = ''
        state_file="$HOME/.local/state/caelestia/scheme.json"
        mode="dark"
        if [ -f "$state_file" ]; then
          mode="$(jq -r '.mode // "dark"' "$state_file" 2>/dev/null || echo dark)"
        fi

        if [ "$mode" = "light" ]; then
          theme-dark
        else
          theme-light
        fi
      '';
    })
  ];
}
