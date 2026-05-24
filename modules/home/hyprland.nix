{ ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "hyprlang";
    systemd.enable = true;
    
    settings = {
      monitor = ", preferred, auto, 1";

      "exec-once" = [
        "waybar"
        "mpvpaper -o \"no-audio --loop --keepaspect=no --vf=scale=1920:1080\" eDP-1 /home/anthony/Pictures/Wallpapers/fondo.gif"
        "nm-applet --indicator"
        "blueman-applet"
        "swaync"
        "mkdir -p ~/Pictures/Screenshots"
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
      ];

      env = [
        "XDG_SESSION_TYPE,wayland"
        "XDG_CURRENT_DESKTOP,Hyprland"
        "XDG_SESSION_DESKTOP,Hyprland"
        "XCURSOR_THEME,Bibata-Modern-Classic"
        "XCURSOR_SIZE,24"
      ];

      input = {
        kb_layout = "us,latam";
        kb_variant = ",";
        kb_options = "grp:shifts_toggle,grp_led:scroll";
        follow_mouse = 1;
        touchpad = {
          natural_scroll = true;
        };
      };

      general = {
        gaps_in = 4;
        gaps_out = 8;
        border_size = 2;
        "col.active_border" = "rgba(cba6f7ee) rgba(89b4faee) 45deg";
        "col.inactive_border" = "rgba(585b70ee)";
        layout = "dwindle";
      };

      decoration = {
        rounding = 12;
        active_opacity = 1.0;
        inactive_opacity = 1.0;
        blur = {
          enabled = true;
          size = 3;
          passes = 1;
          new_optimizations = true;
        };
      };

      "$mainMod" = "SUPER";

      bind = [
        "$mainMod, Q, exec, kitty"
        "$mainMod, C, killactive,"
        "$mainMod, M, exit,"
        "$mainMod, E, togglefloating,"
        "$mainMod, R, exec, rofi -show drun"

        "$mainMod, N, exec, swaync-client -t -sw"

        # Productividad
        "$mainMod, V, exec, cliphist list | rofi -dmenu -p \"Portapapeles\" | cliphist decode | wl-copy"
        "$mainMod SHIFT, P, exec, hyprpicker -a && notify-send \"Color Picker\" \"Código copiado\""
        "$mainMod SHIFT, S, exec, grim -g \"$(slurp)\" - | wl-copy && notify-send \"Captura\" \"Área copiada\""
        ", Print, exec, grim ~/Pictures/Screenshots/Captura_$(date +'%Y%m%d_%H%M%S').png && notify-send \"Captura\" \"Guardada\""

        # Navegación
        "$mainMod, left, movefocus, l"
        "$mainMod, right, movefocus, r"
        "$mainMod, up, movefocus, u"
        "$mainMod, down, movefocus, d"
      ];

      bindl = [
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
      ];

      bindle = [
        ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];
    };

    # 🌟 NUEVA SINTAXIS DE BLOQUE PARA REGLAS DE VENTANA (Hyprland 0.53+)
    extraConfig = ''
      windowrule {
          name = terminal-opacity
          match:class = ^(kitty)$
          opacity = 0.85
      }
    '';
  };
}
