{ pkgs, ... }:
let
  backend = pkgs.writeShellApplication {
    name = "fleet-ui-backend";
    runtimeInputs = [ pkgs.coreutils ];
    text = builtins.readFile ../../../scripts/fleet-ui-darwin.sh;
  };
in
{
  fleet.interaction.backend = backend;

  # Karabiner owns only the physical-key normalization. The active profile stays
  # mutable/user-owned; this repository ships an importable Complex Modification
  # instead of replacing Karabiner's device-specific state.
  xdg.configFile."karabiner/assets/complex_modifications/fleet-key.json".source =
    ../../../dotfiles/karabiner/fleet-key.json;

  # Hammerspoon turns F18 into a held modal key. This preserves distinct
  # Fleet+key and Fleet+Shift+key chords, unlike a four-modifier Hyper mapping.
  home.file.".hammerspoon/init.lua".text = ''
    hs.autoLaunch(true)

    local home = os.getenv("HOME")
    local user = os.getenv("USER") or ""
    local candidates = {
      home .. "/.nix-profile/bin/fleet-ui",
    }
    if user ~= "" then
      table.insert(candidates, "/etc/profiles/per-user/" .. user .. "/bin/fleet-ui")
    end

    fleetInteraction = {
      tasks = {},
      nextTaskId = 0,
    }

    local fleetUi = nil
    for _, candidate in ipairs(candidates) do
      if hs.fs.attributes(candidate) then
        fleetUi = candidate
        break
      end
    end

    local function run(args)
      if not fleetUi then
        hs.alert.show("fleet-ui is not available in the active Home Manager profile")
        return
      end

      fleetInteraction.nextTaskId = fleetInteraction.nextTaskId + 1
      local taskId = fleetInteraction.nextTaskId
      local task = hs.task.new(fleetUi, function(exitCode, _, stdErr)
        fleetInteraction.tasks[taskId] = nil
        if exitCode ~= 0 and stdErr and #stdErr > 0 then
          hs.alert.show(stdErr)
        end
      end, nil, args)

      if task then
        fleetInteraction.tasks[taskId] = task
        if not task:start() then
          fleetInteraction.tasks[taskId] = nil
        end
      end
    end

    hs.urlevent.bind("fleet-lock", function()
      hs.eventtap.keyStroke({ "ctrl", "cmd" }, "q")
    end)

    fleetInteraction.modal = hs.hotkey.modal.new()
    local fleet = fleetInteraction.modal

    fleetInteraction.triggers = {
      hs.hotkey.bind({}, "f18",
        function() fleet:enter() end,
        function() fleet:exit() end
      ),
      hs.hotkey.bind({ "shift" }, "f18",
        function() fleet:enter() end,
        function() fleet:exit() end
      ),
    }

    fleet:bind({}, "return", function() run({ "terminal" }) end)
    fleet:bind({}, "space", function() run({ "menu" }) end)
    fleet:bind({}, "b", function() run({ "browser" }) end)
    fleet:bind({}, "t", function() run({ "files" }) end)
    fleet:bind({}, "o", function() run({ "orca" }) end)
    fleet:bind({}, "l", function() run({ "lock" }) end)
    fleet:bind({}, "f", function() run({ "fullscreen" }) end)
    fleet:bind({}, "e", function() run({ "toggle-floating" }) end)
    fleet:bind({}, "s", function() run({ "resize" }) end)
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

    [mode.resize.binding]
    left = 'resize width -50'
    right = 'resize width +50'
    up = 'resize height -50'
    down = 'resize height +50'
    enter = 'mode main'
    esc = 'mode main'
  '';
}
