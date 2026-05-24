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
        
        # 🌟 ORDEN DE BLOQUE DERECHO COMPLETO Y RESTAURADO
        modules-right = [ "cpu" "memory" "backlight" "pulseaudio" "battery" "network" "bluetooth" "custom/notification" ];

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

        # Módulo de Brillo
        "backlight" = {
          format = "{icon} {percent}%";
          format-icons = [ "󰃞" "󰃟" "󰃠" ];
        };

        # Módulo de Audio
        "pulseaudio" = {
          format = "{icon} {volume}%";
          format-muted = "󰝟 Mute";
          format-icons = {
            default = [ "󰕿" "󰖀" "󰕾" ];
          };
          on-click = "pwvucontrol";
        };

        # Módulo de Batería
        "battery" = {
          states = { "warning" = 30; "critical" = 15; };
          format = "{icon} {capacity}%";
          format-charging = "󱐋 {capacity}%";
          format-icons = [ "󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
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

      #clock, #cpu, #memory, #backlight, #pulseaudio, #battery, #network, #bluetooth, #custom\/notification {
        padding: 0 12px;
        margin: 4px 2px;
        background: rgba(255, 255, 255, 0.08);
        border: 1px solid rgba(255, 255, 255, 0.1);
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
      #custom\/notification { color: #f9e2af; padding-right: 10px; }
    '';
  };
}
