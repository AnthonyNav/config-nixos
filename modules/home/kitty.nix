{ ... }:

{
  # El tema estático de catppuccin.nix para kitty se apaga: los colores ahora
  # los controla Caelestia en vivo (ver modules/home/theme-sync.nix), para que
  # cambiar de esquema en Caelestia también cambie los colores de la terminal.
  catppuccin.kitty.enable = false;

  programs.kitty = {
    enable = true;

    # Necesario para que el postHook de Caelestia pueda recargar los colores
    # de kitty en caliente tras `caelestia scheme set` (ver theme-sync.nix).
    settings = {
      allow_remote_control = "yes";
      listen_on = "unix:/tmp/kitty";

      # Configuración de Ventana y Estética
      background_opacity = "0.85";   # Transparencia facha
      window_padding_width = 12;      # Margen interno elegante
      hide_window_decorations = "yes";
      confirm_os_window_close = 0;

      # Tipografía limpia (Nerd Font para iconos en terminal)
      font_family = "JetBrainsMono Nerd Font";
      font_size = "13.0";

      # Configuración del cursor
      cursor_shape = "beam";
      cursor_blink_interval = "0.5";
    };

    # Al final del archivo (gana sobre `settings` si hubiera solapamiento):
    # incluye los colores generados dinámicamente por el esquema activo de
    # Caelestia. Se regenera cada vez que corres `caelestia scheme set ...`.
    extraConfig = ''
      include ~/.local/state/caelestia/theme/kitty-colors.conf
    '';
  };
}
