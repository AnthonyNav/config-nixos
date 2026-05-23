{ ... }:

{
  programs.kitty = {
    enable = true;
    
    settings = {
      # Configuración de Ventana y Estética
      background_opacity = "0.85";   # Transparencia facha
      window_padding_width = 12;      # Margen interno elegante
      hide_window_decorations = "yes";
      confirm_os_window_close = 0;
      
      # Tipografía limpia (Nerd Font para iconos en terminal)
      font_family = "JetBrainsMono Nerd Font";
      font_size = "11.0";
      
      # Configuración del cursor
      cursor_shape = "beam";
      cursor_blink_interval = "0.5";
    };
  };
}
