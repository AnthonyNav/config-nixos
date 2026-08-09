{ ... }:

{
  # Pantalla de bloqueo (hyprlock) — activar con Super+L o automáticamente.
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        disable_loading_bar = true;
        hide_cursor = true;
        grace = 5; # segundos de gracia antes de pedir contraseña
      };

      background = [
        {
          monitor = "";
          path = "screenshot";
          blur_passes = 3;
          blur_size = 7;
          brightness = 0.5;
        }
      ];

      input-field = [
        {
          monitor = "";
          size = "300, 50";
          outline_thickness = 2;
          inner_color = "rgb(30, 30, 46)"; # Catppuccin Mocha base
          outer_color = "rgb(203, 166, 247)"; # Catppuccin Mocha mauve
          font_color = "rgb(205, 214, 244)"; # text
          fade_on_empty = true;
          placeholder_text = "<i>Password...</i>";
          hide_input = false;
          position = "0, -80";
          halign = "center";
          valign = "center";
        }
      ];

      label = [
        {
          monitor = "";
          text = "$TIME";
          color = "rgb(205, 214, 244)";
          font_size = 64;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, 160";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };

  # Gestión de inactividad (hypridle) — escalonado seguro.
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };

      listener = [
        {
          # 3 min sin actividad → atenuar pantalla al 30%
          timeout = 180;
          on-timeout = "brightnessctl -s set 30%";
          on-resume = "brightnessctl -r";
        }
        {
          # 5 min → bloquear sesión (hyprlock debe estar corriendo ANTES del dpms off)
          timeout = 300;
          on-timeout = "loginctl lock-session";
        }
        {
          # 5 min 30 s → apagar pantalla; hyprlock ya está renderizando y puede despertar limpiamente
          timeout = 330;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        {
          # 30 min sin actividad → suspender el sistema
          timeout = 1800;
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };
}
