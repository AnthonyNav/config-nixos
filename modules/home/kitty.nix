_:

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
      # Theme reloads use the local socket. Reject control sequences from a
      # program's terminal output, including remote SSH sessions.
      allow_remote_control = "socket-only";
      listen_on = "unix:/tmp/kitty";

      # Configuración de Ventana y Estética
      background_opacity = "0.94";
      dynamic_background_opacity = true;
      window_padding_width = 12; # Margen interno elegante
      hide_window_decorations = "yes";
      confirm_os_window_close = 0;

      # Tipografía limpia (Nerd Font para iconos en terminal)
      font_family = "JetBrainsMono Nerd Font";
      font_size = "13.0";

      # Configuración del cursor
      cursor_shape = "beam";
      cursor_blink_interval = "0.5";
    };

    # App actions use Super like Command on macOS. Native Ctrl+C/Ctrl+Z keep
    # reaching the foreground terminal program; no global modifier swap.
    keybindings = {
      "super+c" = "copy_to_clipboard";
      "super+v" = "paste_from_clipboard";
      "super+t" = "new_tab";
      "super+n" = "new_os_window";
      "super+w" = "close_tab";
      "super+q" = "quit";
      "super+shift+c" = "copy_to_clipboard";
      "super+shift+v" = "paste_from_clipboard";
    };

    # Al final del archivo (gana sobre `settings` si hubiera solapamiento):
    # incluye los colores generados dinámicamente por el esquema activo de
    # Caelestia. Se regenera cada vez que corres `caelestia scheme set ...`.
    extraConfig = ''
      include ~/.local/state/caelestia/theme/kitty-colors.conf
      include ~/.local/state/caelestia/theme/kitty-opacity.conf
    '';
  };
}
