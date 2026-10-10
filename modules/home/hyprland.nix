{ config, lib, ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "hyprlang";
    systemd.enable = true;

    settings = {
      # Safe startup default; monitor-layout owns connected topologies.
      monitor = lib.mkDefault ", preferred, auto, 1";

      "exec-once" = [
        # Caelestia Shell se autoarranca vía su propio servicio systemd --user
        # (programs.caelestia.systemd.enable, ver modules/home/caelestia.nix);
        # no necesita exec-once aquí. Tampoco lo necesita el wallpaper: es la
        # gestión nativa de Caelestia (background.wallpaperEnabled = true),
        # se pinta sola al arrancar el shell.
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

      # Super remains available to applications. Desktop commands use the menu.
      bind = [
        "SUPER ALT, Return, exec, fleet-ui menu-hotkey"
        "SUPER SHIFT, 3, exec, fleet-ui screenshot screen --file auto"
        "SUPER SHIFT, 4, exec, fleet-ui screenshot area --file auto"
        "SUPER SHIFT, 5, exec, fleet-ui media-menu"
        "ALT, Tab, cyclenext,"
        "ALT, Tab, bringactivetotop,"
        "ALT SHIFT, Tab, cyclenext, prev"
        "ALT SHIFT, Tab, bringactivetotop,"
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

      # Preserve the existing mouse gestures without reserving app keys.
      bindm = [
        "SUPER, mouse:272, movewindow"
        "SUPER, mouse:273, resizewindow"
      ];

      # Nota: no hay bloque de reglas de ventana (windowrule/windowrulev2).
      # Desde Hyprland 0.55 esa sintaxis hyprlang quedó deprecada a favor de
      # Lua (hl.window_rule({...})), y configType acá es "hyprlang" para todo
      # el archivo — migrar solo esto a Lua obligaría a reescribir el resto
      # de la config (binds, general, decoration...) a ese formato nuevo y
      # aún inestable. Se deja pendiente como proyecto aparte si hace falta.
    };

    # Modes are explicit: bare arrows/numbers are consumed only after entering.
    # Escape/Enter leave through the adapter, including its visible indicator.
    extraConfig = ''
      source = ${config.xdg.stateHome}/caelestia/theme/hyprland-colors.conf
      source = ${config.xdg.stateHome}/caelestia/theme/hyprland-preset.conf
      submap = fleet-move
      binde = , left, movewindow, l
      binde = , right, movewindow, r
      binde = , up, movewindow, u
      binde = , down, movewindow, d
      bind = , 1, exec, fleet-ui move-workspace 1
      bind = , 2, exec, fleet-ui move-workspace 2
      bind = , 3, exec, fleet-ui move-workspace 3
      bind = , 4, exec, fleet-ui move-workspace 4
      bind = , 5, exec, fleet-ui move-workspace 5
      bind = , 6, exec, fleet-ui move-workspace 6
      bind = , 7, exec, fleet-ui move-workspace 7
      bind = , 8, exec, fleet-ui move-workspace 8
      bind = , 9, exec, fleet-ui move-workspace 9
      bind = , 0, exec, fleet-ui move-workspace 10
      bindi = , Escape, exec, fleet-ui mode-exit
      bindi = , Return, exec, fleet-ui mode-exit
      submap = fleet-resize
      binde = , right, resizeactive,  20 0
      binde = , left,  resizeactive, -20 0
      binde = , up,    resizeactive,  0 -20
      binde = , down,  resizeactive,  0  20
      bindi = , Escape, exec, fleet-ui mode-exit
      bindi = , Return, exec, fleet-ui mode-exit
      submap = reset
    '';
  };
}
