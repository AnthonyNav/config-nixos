{ username, ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "hyprlang";
    systemd.enable = true;
    
    settings = {
      monitor = ", preferred, auto, 1";

      "exec-once" = [
        # Caelestia Shell se autoarranca vía su propio servicio systemd --user
        # (programs.caelestia.systemd.enable, ver modules/home/caelestia.nix);
        # no necesita exec-once aquí.
        "mpvpaper -o \"no-audio --loop --keepaspect=no --vf=scale=1920:1080\" eDP-1 /home/${username}/Pictures/Wallpapers/fondo.gif"
        # nm-applet y blueman-applet quitados: eran íconos de bandeja
        # duplicados; Caelestia ya tiene control nativo de red y bluetooth
        # (contenedor statusIcons + sidebar de quick toggles).
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
        # Gestión del Sistema y Terminal
        "$mainMod, Return, exec, kitty"
        "$mainMod, R, exec, caelestia shell drawers toggle launcher"   # launcher nativo de Caelestia (antes rofi -show drun)
        "$mainMod, D, global, caelestia:dashboard"                     # dashboard (media, clima, info del sistema)
        "$mainMod, C, killactive,"
        "$mainMod, Q, killactive,"          # alias estándar de i3/sway
        "$mainMod, F, fullscreen, 0"

        # Sesión y Energía
        "$mainMod, L, exec, pidof hyprlock || hyprlock"            # bloquear pantalla
        "$mainMod, Escape, global, caelestia:session"              # menú de sesión nativo de Caelestia (antes wlogout)
        "$mainMod, M, exit,"                                       # salida de emergencia (sin menú)

        # Modos de Ordenamiento y Ventanas
        "$mainMod, E, togglefloating,"
        "$mainMod, G, togglegroup,"
        "$mainMod, Tab, changegroupactive, f"

        # Lanzadores Rápidos
        "$mainMod, B, exec, firefox"
        "$mainMod, T, exec, thunar"         # gestor de archivos

        # Cheatsheet de atajos (muestra los binds activos de Hyprland via rofi)
        "$mainMod SHIFT, K, exec, hyprctl binds -j | jq -r '.[] | \"\\(.modmask)\\t\\(.key)\\t→\\t\\(.dispatcher) \\(.arg)\"' | column -t | rofi -dmenu -i -p \"Atajos de teclado\""

        # Control de Notificaciones (Caelestia Shell, antes SwayNC)
        "$mainMod, N, exec, caelestia shell drawers toggle sidebar"    # panel de notifs + quick toggles
        "$mainMod ALT, N, exec, caelestia shell notifs clear"          # limpiar todas las notificaciones

        # Herramientas de Productividad
        "$mainMod, V, exec, cliphist list | rofi -dmenu -p \"Portapapeles\" | cliphist decode | wl-copy"
        "$mainMod SHIFT, P, exec, hyprpicker -a && notify-send \"Color Picker\" \"Código copiado\""
        "$mainMod SHIFT, C, exec, caelestia shell picker open"           # color picker nativo de Caelestia (alternativa a hyprpicker)
        "$mainMod SHIFT, S, exec, grim -g \"$(slurp)\" - | wl-copy && notify-send \"Captura\" \"Área copiada\""
        ", Print, exec, grim ~/Pictures/Screenshots/Captura_$(date +'%Y%m%d_%H%M%S').png && notify-send \"Captura\" \"Guardada\""
        "$mainMod SHIFT ALT, S, global, caelestia:screenshotFreeze"      # captura con freeze + anotación (swappy)

        # Luz cálida (filtro azul) — alterna el servicio wlsunset ya existente
        # (modules/home/night-light.nix, auto día/noche). Caelestia no trae
        # control nativo de temperatura de color (confirmado en su código
        # fuente), así que se resuelve con este atajo en vez de parchar el shell.
        "$mainMod SHIFT, W, exec, systemctl --user is-active --quiet wlsunset.service && (systemctl --user stop wlsunset.service && notify-send 'Luz cálida' 'Desactivada') || (systemctl --user start wlsunset.service && notify-send 'Luz cálida' 'Activada (automática)')"

        # Navegación del Foco
        "$mainMod, left, movefocus, l"
        "$mainMod, right, movefocus, r"
        "$mainMod, up, movefocus, u"
        "$mainMod, down, movefocus, d"
        "$mainMod CTRL, right, workspace, e+1"
        "$mainMod CTRL, left, workspace, e-1"

        # Intercambio Físico de Ventanas
        "$mainMod SHIFT, left, movewindow, l"
        "$mainMod SHIFT, right, movewindow, r"
        "$mainMod SHIFT, up, movewindow, u"
        "$mainMod SHIFT, down, movewindow, d"

        # --- NAVEGACIÓN DE ESCRITORIOS (WORKSPACES) ---
        "$mainMod, 1, workspace, 1"
        "$mainMod, 2, workspace, 2"
        "$mainMod, 3, workspace, 3"
        "$mainMod, 4, workspace, 4"
        "$mainMod, 5, workspace, 5"
        "$mainMod, 6, workspace, 6"
        "$mainMod, 7, workspace, 7"
        "$mainMod, 8, workspace, 8"
        "$mainMod, 9, workspace, 9"
        "$mainMod, 0, workspace, 10"

        # --- MOVER VENTANAS A OTROS ESCRITORIOS ---
        "$mainMod SHIFT, 1, movetoworkspace, 1"
        "$mainMod SHIFT, 2, movetoworkspace, 2"
        "$mainMod SHIFT, 3, movetoworkspace, 3"
        "$mainMod SHIFT, 4, movetoworkspace, 4"
        "$mainMod SHIFT, 5, movetoworkspace, 5"
        "$mainMod SHIFT, 6, movetoworkspace, 6"
        "$mainMod SHIFT, 7, movetoworkspace, 7"
        "$mainMod SHIFT, 8, movetoworkspace, 8"
        "$mainMod SHIFT, 9, movetoworkspace, 9"
        "$mainMod SHIFT, 0, movetoworkspace, 10"
        "$mainMod, mouse_down, workspace, e+1"
        "$mainMod, mouse_up, workspace, e-1"
      ];

      bindl = [
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"

        # Controles de medios (antes sin usar) — atajos globales de Caelestia
        ", XF86AudioPlay, global, caelestia:mediaToggle"
        ", XF86AudioNext, global, caelestia:mediaNext"
        ", XF86AudioPrev, global, caelestia:mediaPrev"
        ", XF86AudioStop, global, caelestia:mediaStop"
      ];

      bindle = [
        ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"

        # Brillo vía Caelestia: mismo brightnessctl por debajo, pero con OSD visual
        ", XF86MonBrightnessUp, global, caelestia:brightnessUp"
        ", XF86MonBrightnessDown, global, caelestia:brightnessDown"
      ];

    };

    # Submap de resize: Super+S activa el modo; flechas redimensionan la
    # ventana activa; Escape o Enter vuelven al modo normal.
    extraConfig = ''
      bind = $mainMod, S, submap, resize
      submap = resize
      binde = , right, resizeactive,  20 0
      binde = , left,  resizeactive, -20 0
      binde = , up,    resizeactive,  0 -20
      binde = , down,  resizeactive,  0  20
      bind  = , Escape, submap, reset
      bind  = , Return, submap, reset
      submap = reset
    '';
  };
}
