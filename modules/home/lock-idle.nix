{ config, ... }:

let
  lockCommand = "${config.programs.caelestia.cli.package}/bin/caelestia shell lock lock";
in
{
  # Caelestia es el unico session locker. Ejecutar Hyprlock en paralelo hace
  # competir dos clientes ext-session-lock y termina derribando Quickshell.
  programs.hyprlock.enable = false;

  # Hypridle conserva la politica de tiempos, brillo, DPMS y suspension.
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = lockCommand;
        before_sleep_cmd = lockCommand;
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
          # 5 min → bloquear antes de apagar las pantallas.
          timeout = 300;
          on-timeout = lockCommand;
        }
        {
          # 5 min 30 s → apagar pantalla; el lock ya esta renderizando.
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
