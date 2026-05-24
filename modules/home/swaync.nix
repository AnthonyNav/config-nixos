{ ... }:

{
  catppuccin.swaync.enable = false;

  services.swaync = {
    enable = true;
    settings = {
      positionX = "right";
      positionY = "top";
      layer = "overlay";
      control-center-width = 360; # 🛠️ Ajuste de ancho exacto y proporcional
      
      widgets = [
        "title"
        "dnd"
        "mpris"
        "volume"
        "backlight"
        "buttons-grid"
        "notifications"
      ];

      widget-config = {
        title = { text = "Centro de Control"; clear-all-button = true; button-text = "Limpiar"; };
        dnd = { text = "No Molestar"; };
        volume = { label = "󰕾 "; };
        backlight = { label = "󰃠 "; };
        mpris = { image-size = 60; image-radius = 8; };
        buttons-grid = {
          actions = [
            { label = "󰖩  Wi-Fi"; command = "networkmanager_dmenu"; }
            { label = "  Bluetooth"; command = "overskride"; }
          ];
        };
      };
    };
    
    style = ''
      * { font-family: "JetBrainsMono Nerd Font"; font-weight: bold; }

      .notification-center {
        background: rgba(30, 30, 46, 0.15);
        border: 1px solid rgba(255, 255, 255, 0.15);
        border-radius: 16px;
        color: #cdd6f4;
        padding: 16px;
        margin: 10px;
      }

      /* 🛠️ CORRECCIÓN DE CONTENEDOR VACÍO (Remueve iconos gigantes genéricos) */
      .control-center .label-waiting {
        font-size: 14px;
        color: #a6adc8;
        opacity: 0.6;
        padding: 40px 0;
        background-image: none; /* Elimina cualquier icono o recurso de imagen previo */
      }

      .widget-title { font-size: 18px; color: #cba6f7; margin-bottom: 10px; }
      .widget-title button {
        background: rgba(255, 255, 255, 0.08);
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 8px;
        color: #cdd6f4;
        padding: 4px 12px;
      }

      .widget-dnd { background: rgba(255, 255, 255, 0.05); padding: 8px; border-radius: 10px; border: 1px solid rgba(255, 255, 255, 0.05); color: #f5c2e7; }
      .widget-volume, .widget-backlight { background: rgba(255, 255, 255, 0.06); padding: 12px; margin: 8px 0; border-radius: 12px; border: 1px solid rgba(255, 255, 255, 0.05); }
      
      scale trough { background: rgba(255, 255, 255, 0.1); border-radius: 4px; min-height: 8px; }
      scale highlight { background: #cba6f7; border-radius: 4px; }

      .widget-mpris { background: rgba(255, 255, 255, 0.08); padding: 14px; margin: 8px 0; border-radius: 14px; border: 1px solid rgba(255, 255, 255, 0.1); color: #cdd6f4; }
      .widget-buttons-grid grid button { background: rgba(255, 255, 255, 0.06); border: 1px solid rgba(255, 255, 255, 0.08); border-radius: 10px; color: #cdd6f4; padding: 10px; margin: 4px; }
      .widget-buttons-grid grid button:hover { background: rgba(255, 255, 255, 0.15); border-color: rgba(255, 255, 255, 0.2); }

      .notification { background: rgba(255, 255, 255, 0.05); border: 1px solid rgba(255, 255, 255, 0.08); border-radius: 12px; margin: 6px 0; padding: 12px; color: #cdd6f4; }
      .notification-title { color: #89b4fa; font-size: 14px; }
    '';
  };
}
