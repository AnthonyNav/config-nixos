let
  preset = mode: focus: {
    inherit mode;
    shell = {
      appearance = {
        transparency = {
          enabled = !focus && mode == "dark";
          base = 0.94;
          layers = 0.85;
        };
        anim.durations.scale = if focus then 0 else 0.8;
        spacing.scale = if focus then 0.9 else 1;
        padding.scale = if focus then 0.9 else 1;
      };
      bar = {
        activeWindow.compact = focus;
        workspaces = {
          showWindows = !focus;
          maxWindowIcons = 3;
        };
        clock.showDate = !focus;
      };
      background.desktopClock.enabled = false;
    };
    hyprland = ''
      general {
        gaps_in = ${if focus then "3" else "4"}
        gaps_out = ${if focus then "6" else "8"}
      }
      decoration {
        rounding = ${if focus then "8" else "12"}
        blur:enabled = ${if focus then "false" else "true"}
      }
      animations:enabled = ${if focus then "false" else "true"}
    '';
  };
in
{
  diario = preset "dark" false;
  claro = preset "light" false;
  enfoque = preset "dark" true;
}
