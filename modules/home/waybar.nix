{ ... }:

{
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        margin-top = 8;
        margin-left = 10;
        margin-right = 10;
        spacing = 4;

        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ "clock" ];
        modules-right = [ "network" "cpu" "memory" "battery" "pulseaudio" ];

        "hyprland/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
        };

        "clock" = {
          format = "  {:%I:%M %p}";
        };

        "cpu" = { format = " {usage}%"; };
        "memory" = { format = " {used}GB"; };

        "battery" = {
          states = { critical = 15; };
          format = "{icon} {capacity}%";
          format-icons = [ "" "" "" "" "" ];
        };

        "network" = {
          format-wifi = " {essid}";
          format-ethernet = " {ipaddr}";
          format-disconnected = "Disconnected";
        };

        "pulseaudio" = {
          format = "{icon} {volume}%";
          format-muted = " Muted";
          format-icons = { default = [ "" "" "" ]; };
        };
      };
    };

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", sans-serif;
        font-size: 13px;
        font-weight: bold;
        border: none;
        border-radius: 0;
      }

      window#waybar {
        background-color: rgba(30, 30, 46, 0.85);
        border: 2px solid rgba(203, 166, 247, 0.4);
        border-radius: 12px;
        color: #cdd6f4;
      }

      #workspaces button {
        padding: 0 8px;
        color: #585b70;
      }

      #workspaces button.active {
        color: #cba6f7;
      }

      #clock, #network, #cpu, #memory, #battery, #pulseaudio {
        padding: 0 12px;
        margin: 4px 2px;
        border-radius: 8px;
        background-color: rgba(17, 17, 27, 0.6);
      }

      #clock { color: #b4befe; }
      #battery { color: #a6e3a1; }
      #network { color: #89b4fa; }
      #pulseaudio { color: #f9e2af; }
    '';
  };
}
