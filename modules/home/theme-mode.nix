{ pkgs, ... }:

{
  # `theme-light`, `theme-dark`, `theme-toggle`: ejecutables reales instalados
  # vía home.packages (NO funciones de zsh, ver el comentario en zsh.nix) —
  # porque también se disparan desde el atajo de Hyprland (Super+Shift+T,
  # hyprland.nix), y `exec` de Hyprland corre el comando vía `sh -c`, no zsh:
  # una función de zsh ahí no existiría (mismo bug ya documentado para
  # rofi/.desktop en gpu-launchers.nix).
  #
  # El wallpaper ya NO se gestiona aquí: se retiraron `set-wallpaper` y
  # `set-wallpaper-output` (mpvpaper + overrides por monitor) a favor de la
  # gestión nativa de Caelestia (`background.wallpaperEnabled = true` en
  # caelestia.nix, elegido desde su selector visual — ver README.md,
  # "Wallpapers").
  home.packages = [
    # Van por el interceptor de modules/home/caelestia-scheme.nix: un
    # `caelestia scheme set -m <modo>` sin --flavour/--name se traduce solo a
    # Catppuccin mocha (dark) o latte (light). El postHook (caelestia.nix) ya
    # se encarga de kitty + GTK3 — no hace falta nada más aquí.
    (pkgs.writeShellApplication {
      name = "theme-light";
      text = "caelestia scheme set --notify -m light";
    })

    (pkgs.writeShellApplication {
      name = "theme-dark";
      text = "caelestia scheme set --notify -m dark";
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
