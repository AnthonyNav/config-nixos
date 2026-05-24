{ ... }:

{
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 36;
        spacing = 4;
        margin-top = 6;
        margin-left = 8;
        margin-right = 8;

        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ "clock" ];
        modules-right = [ "cpu" "memory" "backlight" "pulseaudio" "battery" "custom/performance" "network" "bluetooth" "custom/notification" ];

        "hyprland/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
          format = "{name}";
        };

        "clock" = {
          format = "󰃭 {:%d %b | 󱑒 %H:%M}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };

        "cpu" = { format = " {usage}%"; interval = 2; };
        "memory" = { format = " {percentage}%"; interval = 2; };

        "backlight" = {
          format = "{icon} {percent}%";
          format-icons = [ "󰃞" "󰃟" "󰃠" ];
        };

        "pulseaudio" = {
          format = "{icon} {volume}%";
          format-muted = "󰝟 Mute";
          format-icons = { default = [ "󰕿" "󰖀" "󰕾" ]; };
          on-click = "pwvucontrol";
        };

        "battery" = {
          states = { "warning" = 30; "critical" = 15; };
          format = "{icon} {capacity}%";
          format-charging = "󱐋 {capacity}%";
          format-icons = [ "󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
        };

        # 🌟 MÓDULO EXCLUSIVO POR ICONOS (Balanza, Rayo, Hoja)
        "custom/performance" = {
          exec = "current=$(powerprofilesctl get); if [ \"$current\" = \"performance\" ]; then echo '{\"text\":\"󱐌\",\"class\":\"perf\",\"tooltip\":\"Modo: Rendimiento Extremo\"}'; elif [ \"$current\" = \"balanced\" ]; then echo '{\"text\":\"󰓅\",\"class\":\"bal\",\"tooltip\":\"Modo: Balanceado\"}'; else echo '{\"text\":\"󰌪\",\"class\":\"save\",\"tooltip\":\"Modo: Ahorro de Energía\"}'; fi";
          interval = 1;
          return-type = "json";
          format = "{}";
          on-click = "current=$(powerprofilesctl get); if [ \"$current\" = \"balanced\" ]; then powerprofilesctl set performance; elif [ \"$current\" = \"performance\" ]; then powerprofilesctl set power-saver; else powerprofilesctl set balanced; fi; notify-send 'Rendimiento' \"Modo cambiado a $(powerprofilesctl get)\"";
        };

        "network" = {
          format-wifi = "  {essid}";
          format-ethernet = "󰈀 Wired";
          format-disconnected = "󰖪 Down";
        };

        "bluetooth" = {
          format = " On";
          format-disabled = "󰂲 Off";
          format-connected = "󰂱 {device_alias}";
        };

        "custom/notification" = {
          tooltip = false;
          format = "{icon}";
          format-icons = {
            notification = "󱅫 ";
            none = "󰂚 ";
            dnd-notification = "󱅫 ";
            dnd-none = "󰂛 ";
          };
          return-type = "json";
          exec-if = "which swaync-client";
          exec = "swaync-client -swb";
          on-click = "swaync-client -t -sw";
          escape = true;
        };
      };
    };

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 13px;
        font-weight: bold;
        border: none;
        border-radius: 0;
      }

      window#waybar {
        background: rgba(30, 30, 46, 0.15);
        border: 1px solid rgba(255, 255, 255, 0.15);
        border-radius: 12px;
        color: #cdd6f4;
      }

      #workspaces button {
        padding: 0 10px;
        color: #6c7086;
        background: transparent;
      }

      #workspaces button.active { color: #cba6f7; }

      /* Píldoras base para módulos regulares */
      #clock, #cpu, #memory, #backlight, #pulseaudio, #battery, #network, #bluetooth {
        padding: 0 12px;
        margin: 4px 2px;
        background: rgba(255, 255, 255, 0.08);
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 8px;
        color: #cdd6f4;
      }

      /* Burbujas independientes para rendimiento y notificaciones */
      #custom-performance,
      #custom-notification {
        padding: 0 12px;
        margin: 4px 6px;
        background: rgba(255, 255, 255, 0.08);
        border: 1px solid rgba(255, 255, 255, 0.12);
        border-radius: 8px;
        color: #cdd6f4;
      }

      #clock { color: #f5c2e7; }
      #cpu { color: #89b4fa; }
      #memory { color: #a6e3a1; }
      #backlight { color: #f9e2af; }
      #pulseaudio { color: #efa5e8; }
      #battery { color: #e8a2af; }
      #network { color: #89dceb; }
      #bluetooth { color: #b4befe; }
      
      #custom-notification { color: #f9e2af; }

      /* ⚡ Dinámica de Colores para las Clases del Perfil de Energía */
      #custom-performance.perf { color: #f38ba8; font-size: 15px; } /* Rayo Rojo Pastel */
      #custom-performance.bal { color: #89b4fa; font-size: 15px; }  /* Balanza Azul */
      #custom-performance.save { color: #a6e3a1; font-size: 15px; } /* Hoja Verde */
    '';
  };
}
