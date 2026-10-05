{ lib }:
let
  presets = import ./caelestia-presets.nix;
  native = name: icon: description: command: {
    inherit
      name
      icon
      description
      command
      ;
  };
in
{
  inherit presets;
  colours = { inherit (import ./catppuccin-palette.nix) dark light; };
  defaults = lib.recursiveUpdate presets.diario.shell {
    appearance.font = {
      headline.family = "Rubik";
      title.family = "Rubik";
      body.family = "Rubik";
      label.family = "Rubik";
      mono.family = "JetBrainsMono Nerd Font";
    };
    general.apps = {
      terminal = [ "kitty" ];
      audio = [ "pavucontrol" ];
      explorer = [ "thunar" ];
    };
    launcher.favouriteApps = [
      "firefox"
      "kitty"
      "thunar"
    ];
    bar.workspaces = {
      shown = 5;
      perMonitorWorkspaces = true;
      activeIndicator = true;
      occupiedBg = true;
    };
    dashboard = {
      resourceUpdateInterval = 1000;
      performance.showGpu = true;
    };
  };
  nativeActions = [
    (native "Calculator" "calculate" "Calcular" [
      "autocomplete"
      "calc"
    ])
    (native "Scheme" "palette" "Elegir esquema" [
      "autocomplete"
      "scheme"
    ])
    (native "Wallpaper" "image" "Elegir fondo" [
      "autocomplete"
      "wallpaper"
    ])
    (native "Variant" "colors" "Elegir variante" [
      "autocomplete"
      "variant"
    ])
    (native "Random" "casino" "Fondo aleatorio" [
      "caelestia"
      "wallpaper"
      "-r"
    ])
    (native "Light" "light_mode" "Modo claro" [
      "setMode"
      "light"
    ])
    (native "Dark" "dark_mode" "Modo oscuro" [
      "setMode"
      "dark"
    ])
    (native "Lock" "lock" "Bloquear sesión" [
      "caelestia"
      "shell"
      "lock"
      "lock"
    ])
    (native "Settings" "settings" "Personalizar desde Nexus" [
      "caelestia"
      "shell"
      "nexus"
      "open"
    ])
  ];
  actions = [
    (native "Perfil: Diario" "dark_mode" "Catppuccin Mocha · lavanda" [
      "desktop-preset"
      "apply"
      "diario"
    ])
    (native "Perfil: Claro" "light_mode" "Catppuccin Latte · alto contraste" [
      "desktop-preset"
      "apply"
      "claro"
    ])
    (native "Perfil: Enfoque" "center_focus_strong" "Menos movimiento y distracciones" [
      "desktop-preset"
      "apply"
      "enfoque"
    ])
    (native "Luz cálida" "nightlight" "Alternar filtro automático" [ "night-light-toggle" ])
    (native "No molestar" "notifications_off" "Alternar notificaciones" [
      "caelestia"
      "shell"
      "notifs"
      "toggleDnd"
    ])
    (native "Audio" "graphic_eq" "Rutas de audio y dispositivos" [ "qpwgraph" ])
    (native "Diagnóstico del equipo" "monitor_heart" "Servicios, memoria y sesión" [
      "kitty"
      "--hold"
      "-e"
      "workstation-doctor"
    ])
    (native "Monitores" "desktop_windows" "Consultar disposición actual" [
      "kitty"
      "--hold"
      "-e"
      "hyprctl"
      "monitors"
    ])
    (native "Captura con anotación" "screenshot" "Capturar, congelar y anotar" [
      "hyprctl"
      "dispatch"
      "global"
      "caelestia:screenshotFreeze"
    ])
  ];
}
