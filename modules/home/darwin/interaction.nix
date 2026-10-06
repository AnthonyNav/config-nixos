{ ... }:
{
  # Karabiner owns only the physical-key normalization. The active profile stays
  # mutable/user-owned; this repository ships an importable Complex Modification
  # instead of replacing Karabiner's device-specific state.
  xdg.configFile."karabiner/assets/complex_modifications/fleet-key.json".text =
    builtins.toJSON {
      title = "Fleet Key";
      rules = [
        {
          description = "Caps Lock becomes the Fleet Key (F18)";
          manipulators = [
            {
              type = "basic";
              from = {
                key_code = "caps_lock";
                modifiers.optional = [ "any" ];
              };
              to = [
                {
                  key_code = "f18";
                }
              ];
            }
          ];
        }
      ];
    };

  # Hammerspoon turns F18 into a held modal key. This preserves distinct
  # Fleet+key and Fleet+Shift+key chords, unlike a four-modifier Hyper mapping.
  home.file.".hammerspoon/init.lua".text = ''
    hs.autoLaunch(true)

    local home = os.getenv("HOME")
    local fleetUi = home .. "/.nix-profile/bin/fleet-ui"

    local function run(args)
      if not hs.fs.attributes(fleetUi) then
        hs.alert.show("fleet-ui is not available in the active Home Manager profile")
        return
      end

      local task = hs.task.new(fleetUi, function(exitCode, _, stdErr)
        if exitCode ~= 0 and stdErr and #stdErr > 0 then
          hs.alert.show(stdErr)
        end
      end, args)
      if task then
        task:start()
      end
    end

    hs.urlevent.bind("fleet-lock", function()
      hs.caffeinate.lockScreen()
    end)

    local fleet = hs.hotkey.modal.new()

    hs.hotkey.bind({}, "f18",
      function() fleet:enter() end,
      function() fleet:exit() end
    )

    fleet:bind({}, "return", function() run({ "terminal" }) end)
    fleet:bind({}, "space", function() run({ "menu" }) end)
    fleet:bind({}, "b", function() run({ "browser" }) end)
    fleet:bind({}, "t", function() run({ "files" }) end)
    fleet:bind({}, "o", function() run({ "orca" }) end)
    fleet:bind({}, "l", function() run({ "lock" }) end)
    fleet:bind({}, "f", function() run({ "fullscreen" }) end)
    fleet:bind({}, "k", function() run({ "shortcuts" }) end)

    local directions = { "left", "right", "up", "down" }
    for _, direction in ipairs(directions) do
      fleet:bind({}, direction, function() run({ "focus", direction }) end)
      fleet:bind({ "shift" }, direction, function() run({ "move", direction }) end)
    end

    for workspace = 1, 9 do
      local key = tostring(workspace)
      local target = tostring(workspace)
      fleet:bind({}, key, function() run({ "workspace", target }) end)
      fleet:bind({ "shift" }, key, function() run({ "move-workspace", target }) end)
    end

    fleet:bind({}, "0", function() run({ "workspace", "10" }) end)
    fleet:bind({ "shift" }, "0", function() run({ "move-workspace", "10" }) end)
  '';

  # AeroSpace supplies the keyboard-oriented window/workspace backend. No
  # appearance, gaps, wallpaper, borders or other visual preferences are owned
  # here.
  home.file.".aerospace.toml".text = ''
    config-version = 2
    start-at-login = true
    auto-reload-config = true
    enable-normalization-flatten-containers = true
    enable-normalization-opposite-orientation-for-nested-containers = true
    default-root-container-layout = 'tiles'
    default-root-container-orientation = 'auto'

    [mode.main.binding]
  '';
}
