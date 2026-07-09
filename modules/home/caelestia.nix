{ inputs, ... }:

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
        # Tras cada `caelestia scheme set` (o Scheme/Variant desde el
        # launcher), recarga los colores de kitty en caliente vía su socket
        # de control remoto (ver modules/home/kitty.nix y theme-sync.nix).
        theme.postHook = "kitty @ --to unix:/tmp/kitty set-colors -a -c ~/.local/state/caelestia/theme/kitty-colors.conf 2>/dev/null || true";
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
