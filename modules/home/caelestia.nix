{ inputs, pkgs, ... }:

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

    set-wallpaper || true
  '';
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

    settings = {
      # Caelestia trae su PROPIA gestión de inactividad (lock/dpms/suspend
      # vía general.idle.timeouts). La desactivamos por completo para que
      # NO compita con hypridle+hyprlock (modules/home/lock-idle.nix), que
      # ya tiene el fix de orden DPMS aplicado y probado.
      general.idle.timeouts = [ ];

      paths = {
        wallpaperDir = "~/Pictures/Wallpapers";
      };

      # La ventana de fondo propia de Caelestia (capa "background" de Wayland)
      # se pinta de negro sólido cuando no hay wallpaper asignado dentro de
      # su propio gestor, tapando nuestro mpvpaper (gif animado). La
      # desactivamos para que mpvpaper siga siendo el único dueño del fondo.
      background.wallpaperEnabled = false;

      bar.status = {
        showBattery = true;
        # showBluetooth queda en su default (true): este es el bluetooth del
        # contenedor statusIcons (wifi + bluetooth + rendimiento), el que sí
        # queremos conservar. El duplicado real era el ícono de blueman-applet
        # en la bandeja del sistema (tray), antes del reloj — ver hyprland.nix.
      };
      # El icono de batería vive dentro de statusIcons; al abrir ese popout,
      # Caelestia muestra el porcentaje y el tiempo restante.
      bar.popouts.statusIcons = true;

      # También deja visible la tarjeta de batería en el dashboard de Caelestia.
      dashboard.performance.showBattery = true;
    };
  };
}
