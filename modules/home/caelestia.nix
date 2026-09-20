{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  # Tras cada cambio de esquema (comando, atajo o el switch claro/oscuro del
  # panel de Caelestia, ver modules/home/caelestia-scheme.nix para el porqué
  # ese switch necesita el wrapper de la CLI): recarga kitty (ya existía),
  # corrige el tema GTK3 y relanza el fondo acorde al modo.
  #
  # apply_gtk() en caelestia-cli (utils/theme.py) fija el tema GTK a
  # "adw-gtk3-dark" SIEMPRE, sin importar el modo — solo ajusta
  # color-scheme/icon-theme vía dconf. Sin este fix, Thunar (GTK3) se quedaría
  # oscuro en modo claro aunque el resto de la UI ya esté en Latte.
  postHook = pkgs.writeShellScript "caelestia-post-hook" ''
    # kitty.nix fija `listen_on = "unix:/tmp/kitty"`, pero kitty le SUFIJA el
    # PID a esa ruta (el socket real es /tmp/kitty-<PID>, confirmado con
    # `ls /tmp/kitty*`) — el literal "unix:/tmp/kitty" nunca existe, así que
    # `kitty @ --to unix:/tmp/kitty ...` fallaba en silencio (el `2>/dev/null
    # || true` se tragaba el "no such file or directory") y `set-colors`
    # jamás llegaba a kitty. Efecto observado: ventanas abiertas no se
    # repintaban (-a nunca corría) y las pestañas NUEVAS también salían con
    # los colores viejos, porque -c/--configured (que actualiza los colores
    # "configured" en memoria que usa cada pestaña nueva) tampoco corría.
    # Fix: iterar sobre los sockets reales.
    for sock in /tmp/kitty-*; do
      [ -S "$sock" ] || continue
      kitty @ --to "unix:$sock" set-colors -a -c \
        "$HOME/.local/state/caelestia/theme/kitty-colors.conf" 2>/dev/null || true
    done

    case "''${SCHEME_MODE:-dark}" in
      light) dconf write /org/gnome/desktop/interface/gtk-theme "'adw-gtk3'" ;;
      *) dconf write /org/gnome/desktop/interface/gtk-theme "'adw-gtk3-dark'" ;;
    esac
  '';

  # Valores iniciales, no una politica inmutable. Caelestia necesita escribir
  # shell.json para que los cambios hechos desde Nexus sobrevivan al reinicio.
  caelestiaShellDefaults = pkgs.writeText "caelestia-shell-defaults.json" (
    builtins.toJSON {
      background.wallpaperEnabled = true;
      bar = {
        popouts.statusIcons = true;
        status.showBattery = true;
      };
      dashboard.performance.showBattery = true;
      general.idle.timeouts = [ ];
      nexus.networkRescanInterval = 60000;
      paths.wallpaperDir = "~/Pictures/Wallpapers";
    }
  );
in
{
  # Caelestia Shell — desktop shell sobre quickshell (barra, launcher,
  # dashboard, notificaciones, control center). Reemplaza waybar + swaync
  # como capa visual. Módulo oficial de home-manager del repo upstream.
  imports = [ inputs.caelestia-shell.homeManagerModules.default ];

  programs.caelestia = {
    enable = true;

    # Habilita el binario `caelestia` en el PATH (launcher IPC, wallpapers,
    # esquemas de color, etc.). Necesario para los binds en hyprland.nix.
    cli = {
      enable = true;
      settings = {
        # Ver definición de `postHook` arriba: kitty (ver también kitty.nix y
        # theme-sync.nix) + fix de GTK3 + fondo según modo.
        theme.postHook = "${postHook}";
      };
    };

  };

  # Quickshell/Caelestia has shown unbounded anonymous-memory growth after a
  # long session (about 2.4 GiB resident plus 7.0 GiB swapped on desktop).
  # Keep the desktop usable under a recurrence; the upstream unit already
  # restarts on failure. These caps cover the shell and any children remaining
  # in its cgroup; the patched application launcher uses separate app.slice
  # scopes so launched applications do not share these limits.
  # Do not throttle this interactive shell with MemoryHigh: at 768 MiB it
  # entered sustained direct reclaim even with about 10 GiB of RAM available,
  # stalling the desktop. Keep the hard memory and swap caps for containment.
  # The 1 GiB hard cap also triggered repeated reclaim at the max boundary;
  # allow 2 GiB of resident/accounted memory without expanding swap usage.
  systemd.user.services.caelestia.Service = {
    MemoryAccounting = true;
    MemoryHigh = "infinity";
    MemoryMax = "2G";
    MemorySwapMax = "512M";
  };

  # El modulo upstream enlaza `settings` al store y vuelve shell.json de solo
  # lectura. Al dejar `programs.caelestia.settings` vacio y sembrar este archivo
  # una sola vez, Nexus puede persistir cambios sin que cada switch los borre.
  home.activation.bootstrapCaelestiaShellConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    config_file="${config.xdg.configHome}/caelestia/shell.json"

    if [ -L "$config_file" ]; then
      target="$(${pkgs.coreutils}/bin/readlink "$config_file" || true)"
      case "$target" in
        /nix/store/*) $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -f "$config_file" ;;
      esac
    fi

    if [ ! -e "$config_file" ]; then
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -Dm600 \
        ${caelestiaShellDefaults} "$config_file"
    fi
  '';
}
