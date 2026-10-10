{ lib, pkgs, ... }:
let
  # GI loads these namespaces dynamically; references to GTK alone do not
  # expose transitive typelibs in a writeShellApplication wrapper.
  giPackages = with pkgs; [
    gtk3
    gtk-layer-shell
    glib
    pango
    atk
    gdk-pixbuf
    gobject-introspection
    harfbuzz
  ];
  modeIndicator = pkgs.writeShellApplication {
    name = "fleet-mode-indicator";
    runtimeInputs = [ (pkgs.python3.withPackages (ps: [ ps.pygobject3 ])) ];
    text = ''
      export GI_TYPELIB_PATH=${lib.makeSearchPathOutput "lib" "lib/girepository-1.0" giPackages}
      export LD_LIBRARY_PATH=${lib.makeLibraryPath giPackages}
      exec python3 ${../../../scripts/fleet-mode-indicator.py} "$@"
    '';
  };
  backend = pkgs.writeShellApplication {
    name = "fleet-ui-backend";
    runtimeInputs = [
      modeIndicator
    ]
    ++ (with pkgs; [
      coreutils
      python3
      grim
      slurp
      wl-clipboard
      wf-recorder
      pulseaudio
      jq
      ffmpeg
    ]);
    text = builtins.readFile ../../../scripts/fleet-ui-linux.sh;
  };
  remapper = pkgs.xremap.hyprland;
  modifiers = {
    # Exact matches leave SUPER+ALT desktop shortcuts and native Ctrl intact.
    "Super-c" = "Ctrl-c";
    "Super-v" = "Ctrl-v";
    "Super-x" = "Ctrl-x";
    "Super-a" = "Ctrl-a";
    "Super-z" = "Ctrl-z";
    "Super-Shift-z" = "Ctrl-Shift-z";
    "Super-s" = "Ctrl-s";
    "Super-f" = "Ctrl-f";
    "Super-o" = "Ctrl-o";
    "Super-p" = "Ctrl-p";
    "Super-n" = "Ctrl-n";
    "Super-t" = "Ctrl-t";
    # Native application quit; no compositor kill or process termination.
    "Super-q" = "Ctrl-q";
    "Super-w" = "Ctrl-w";
    "Super-Shift-w" = "Ctrl-Shift-w";
    "Super-Shift-s" = "Ctrl-Shift-s";
  };
  remapConfig = pkgs.writeText "fleet-gui-keybindings.json" (
    builtins.toJSON {
      keymap = [
        {
          name = "Fleet GUI edit actions";
          application.only = [
            "/(?i)^(firefox|firefoxesr|firefox-esr|org\\.mozilla\\.firefox|thunar|org\\.xfce\\.thunar|dbgate)$/"
          ];
          exact_match = true;
          remap = modifiers;
        }
        {
          name = "Fleet browser navigation";
          application.only = [ "/(?i)^(firefox|firefoxesr|firefox-esr|org\\.mozilla\\.firefox)$/" ];
          exact_match = true;
          remap = {
            "Super-Shift-t" = "Ctrl-Shift-t";
            "Super-l" = "Ctrl-l";
            "Super-r" = "Ctrl-r";
            "Super-Shift-r" = "Ctrl-Shift-r";
          };
        }
      ];
    }
  );
in
{
  fleet.interaction.backend = backend;
  xdg.configFile."fleet/gui-keybindings.json".source = remapConfig;
  home.packages = [ remapper ];
  systemd.user.services.fleet-gui-keybindings = {
    Unit = {
      Description = "Fleet application shortcuts for the Hyprland session";
      After = [ "graphical-session.target" ];
      BindsTo = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${remapper}/bin/xremap --desktop hypr --watch=device --allow-launch=false --no-window-logging --output-device-name fleet-xremap ${remapConfig}";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
