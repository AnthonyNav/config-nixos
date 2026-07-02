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
    cli.enable = true;

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
        # Ícono duplicado: ya existe wifi+bluetooth+rendimiento en el panel
        # de quick toggles (sidebar); no hace falta también en la barra.
        showBluetooth = false;
      };
    };
  };
}
