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

      bar.status = {
        showBattery = true;
      };
    };
  };
}
