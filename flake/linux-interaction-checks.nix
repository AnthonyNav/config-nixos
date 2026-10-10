{
  lib,
  pkgs,
  self,
  username,
  workstationNames,
}:
let
  homes = map (name: self.homeConfigurations."${username}@${name}".config) workstationNames;
  systems = map (name: self.nixosConfigurations.${name}.config) workstationNames;
  home = builtins.head homes;
  expectedBindings = [
    "SUPER ALT, Return, exec, fleet-ui menu-hotkey"
    "SUPER SHIFT, 3, exec, fleet-ui screenshot screen --file auto"
    "SUPER SHIFT, 4, exec, fleet-ui screenshot area --file auto"
    "SUPER SHIFT, 5, exec, fleet-ui media-menu"
    "ALT, Tab, cyclenext,"
    "ALT, Tab, bringactivetotop,"
    "ALT SHIFT, Tab, cyclenext, prev"
    "ALT SHIFT, Tab, bringactivetotop,"
  ];
  access =
    system:
    lib.findFirst (
      p: lib.getName p == "fleet-keyboard-input-access"
    ) null system.services.udev.packages;
  policy =
    assert lib.all (h: h.wayland.windowManager.hyprland.settings.bind == expectedBindings) homes;
    assert lib.all (
      h: !lib.hasInfix "caps:" h.wayland.windowManager.hyprland.settings.input.kb_options
    ) homes;
    assert lib.all (
      h:
      lib.hasInfix "submap = fleet-move" h.wayland.windowManager.hyprland.extraConfig
      && lib.hasInfix "submap = fleet-resize" h.wayland.windowManager.hyprland.extraConfig
    ) homes;
    assert lib.all (
      h:
      h.programs.kitty.keybindings."super+c" == "copy_to_clipboard"
      && h.programs.kitty.keybindings."super+q" == "quit"
      && !(h.programs.kitty.keybindings ? "ctrl+c")
      && !(h.programs.kitty.keybindings ? "ctrl+z")
    ) homes;
    assert lib.all (
      h:
      lib.hasInfix "--allow-launch=false --no-window-logging" (
        lib.concatStringsSep " " h.systemd.user.services.fleet-gui-keybindings.Service.ExecStart
      )
    ) homes;
    assert lib.all (
      h: h.systemd.user.services.fleet-gui-keybindings.Unit.BindsTo == [ "graphical-session.target" ]
    ) homes;
    assert lib.all (
      s:
      s.hardware.uinput.enable
      && !builtins.elem "input" s.users.users.${username}.extraGroups
      && !builtins.elem "uinput" s.users.users.${username}.extraGroups
      && access s != null
    ) systems;
    true;
in
{
  editor-bindings =
    pkgs.runCommand "fleet-editor-bindings-check" { nativeBuildInputs = [ pkgs.python3 ]; }
      ''
        python ${../scripts/tests/check-editor-bindings.py} ${../scripts/editor-bindings.py} \
          ${../scripts/ai-opencode.py} ${../dotfiles/vscode/fleet-linux-keybindings.json}
        touch "$out"
      '';
  linux-interaction =
    assert policy;
    pkgs.runCommand "fleet-linux-interaction-check"
      {
        nativeBuildInputs = [
          pkgs.xremap.hyprland
          (pkgs.python3.withPackages (ps: [ ps.pygobject3 ]))
        ];
        GI_TYPELIB_PATH = lib.makeSearchPathOutput "lib" "lib/girepository-1.0" [
          pkgs.gtk3
          pkgs.gtk-layer-shell
          pkgs.glib
          pkgs.pango
          pkgs.atk
          pkgs.gdk-pixbuf
          pkgs.gobject-introspection
          pkgs.harfbuzz
        ];
        LD_LIBRARY_PATH = lib.makeLibraryPath [
          pkgs.gtk3
          pkgs.gtk-layer-shell
          pkgs.glib
          pkgs.pango
          pkgs.atk
          pkgs.gdk-pixbuf
          pkgs.gobject-introspection
          pkgs.harfbuzz
        ];
      }
      ''
        xremap --desktop hypr --watch=device --allow-launch=false --no-window-logging \
          --output-device-name fleet-xremap --validate-config \
          ${home.xdg.configFile."fleet/gui-keybindings.json".source}
        python - ${
          home.xdg.configFile."fleet/gui-keybindings.json".source
        } ${access (builtins.head systems)}/lib/udev/rules.d/65-fleet-keyboard-input.rules <<'PY'
        import gi, json, pathlib, re, sys
        gi.require_version("Gtk", "3.0")
        gi.require_version("GtkLayerShell", "0.1")
        from gi.repository import Gtk, GtkLayerShell
        rules = pathlib.Path(sys.argv[2]).read_text().splitlines()
        assert all('TAG+="uaccess"' in rule for rule in rules)
        assert all('ENV{ID_INPUT_KEYBOARD}=="1"' in rule for rule in rules[:-1])
        assert not any('GROUP=' in rule or 'MODE=' in rule for rule in rules)
        mappings = json.loads(pathlib.Path(sys.argv[1]).read_text())["keymap"]
        assert all(block["exact_match"] for block in mappings)
        allowed = re.compile(mappings[0]["application"]["only"][0][1:-1])
        assert all(allowed.fullmatch(name) for name in ("firefox", "org.mozilla.firefox", "Thunar", "DbGate"))
        assert not any(allowed.fullmatch(name) for name in ("kitty", "Code", "code-oss", "Orca", "org.gnome.Terminal", "dbgate-preview", "Firefox-Debug"))
        assert all(key.startswith("Super-") and "Alt" not in key and value.startswith("Ctrl-") for block in mappings for key, value in block["remap"].items())
        assert mappings[0]["remap"]["Super-q"] == "Ctrl-q"
        PY
        touch "$out"
      '';
}
