-- Fleet's menus are explicit, visible modes. Caps Lock and Ctrl+C/Z/D stay native.
local M = { tasks = {} }
local home = os.getenv("HOME")
local generation, taskID = 0, 0
local stopped, queryPending = false, false
local trigger, watcher, timer

-- Unknown applications keep Cmd+Alt+Enter. An inspected menu only describes
-- exposed menu shortcuts, not hidden/context-dependent application bindings.
local knownApps = {
  ["com.apple.finder"] = true,
  ["com.apple.Safari"] = true,
  ["com.apple.Terminal"] = true,
  ["com.google.Chrome"] = true,
  ["org.mozilla.firefox"] = true,
  ["org.dbgate"] = true,
  ["com.microsoft.VSCode"] = true,
  ["net.kovidgoyal.kitty"] = true,
}
local terminalApps = {
  ["com.apple.Terminal"] = true,
  ["net.kovidgoyal.kitty"] = true,
  ["com.googlecode.iterm2"] = true,
  ["com.mitchellh.ghostty"] = true,
  ["dev.warp.Warp-Stable"] = true,
}
local terminalEdits = { copy = true, paste = true, close = true, ["new-tab"] = true, quit = true }
local editChords = {
  copy = { { "cmd" }, "c" }, paste = { { "cmd" }, "v" }, cut = { { "cmd" }, "x" },
  undo = { { "cmd" }, "z" }, redo = { { "cmd", "shift" }, "z" },
  ["select-all"] = { { "cmd" }, "a" }, save = { { "cmd" }, "s" }, find = { { "cmd" }, "f" },
  open = { { "cmd" }, "o" }, new = { { "cmd" }, "n" }, ["new-tab"] = { { "cmd" }, "t" },
  close = { { "cmd" }, "w" }, quit = { { "cmd" }, "q" },
  location = { { "cmd" }, "l" }, reload = { { "cmd" }, "r" },
}

local function frontApp()
  return hs.application.frontmostApplication()
end

local function sameApp(app)
  local current = frontApp()
  return app and current and app:pid() == current:pid()
end

local function alert(message)
  hs.alert.show(message)
end

local function nativeMenuShortcut(node)
  if type(node) ~= "table" then return false end
  local mods = node.AXMenuItemCmdModifiers
  if type(mods) == "table" then
    local cmd, alt, extra = false, false, false
    for _, modifier in pairs(mods) do
      local value = tostring(modifier):lower()
      if value == "cmd" or value == "command" or value == "⌘" then cmd = true
      elseif value == "alt" or value == "option" or value == "⌥" then alt = true
      else extra = true end
    end
    local key = tostring(node.AXMenuItemCmdChar or ""):lower()
    local glyph = tonumber(node.AXMenuItemCmdGlyph)
    local enter = key == "\r" or key == "\n" or key == "return" or key == "enter"
      or key == "↩" or key == "↵" or key == "⌅"
      or glyph == 4 or glyph == 11 or glyph == 12 or glyph == 13
    if cmd and alt and not extra and enter then return true end
  end
  for _, child in pairs(node) do
    if type(child) == "table" and nativeMenuShortcut(child) then return true end
  end
  return false
end

-- Disable immediately, then inspect asynchronously. A late callback for a
-- previous application can neither enable the trigger nor open a menu.
local function inspectShortcut(onPressed)
  generation = generation + 1
  local request = generation
  trigger:disable()
  queryPending = false
  local app = frontApp()
  if stopped or not app or not knownApps[app:bundleID()] then return end
  queryPending = true
  local ok = pcall(function()
    app:getMenuItems(function(items)
      if request ~= generation or stopped then return end
      queryPending = false
      if not sameApp(app) or M.mode then return end
      local safe = type(items) == "table" and not nativeMenuShortcut(items)
      if safe then
        if onPressed then M.show("main") else trigger:enable() end
      elseif onPressed then
        -- The menu changed after the last inspection: forward the consumed
        -- chord with our hotkey disabled so the application can handle it.
        hs.eventtap.keyStroke({ "cmd", "alt" }, "return", 0, app)
      end
    end)
  end)
  if not ok then
    queryPending = false
    if onPressed and sameApp(app) then
      hs.eventtap.keyStroke({ "cmd", "alt" }, "return", 0, app)
    end
  end
end

local function executable()
  local user = os.getenv("USER") or ""
  for _, path in ipairs({
    home .. "/.nix-profile/bin/fleet-ui",
    "/etc/profiles/per-user/" .. user .. "/bin/fleet-ui",
    "/run/current-system/sw/bin/fleet-ui",
  }) do
    if hs.fs.attributes(path) then return path end
  end
end

local function run(args)
  local path = executable()
  if not path then alert("Fleet: falta fleet-ui en el perfil Nix"); return end
  taskID = taskID + 1
  local id = taskID
  local status = args[1] == "record" and args[2] == "status"
  local task = hs.task.new(path, function(code, stdout, stderr)
    M.tasks[id] = nil
    if code ~= 0 then
      alert("Fleet: " .. (stderr ~= "" and stderr or ("error " .. tostring(code))))
    elseif status and stdout ~= "" then
      alert(stdout)
    end
  end, nil, args)
  if not task then alert("Fleet: no se pudo crear la tarea"); return end
  M.tasks[id] = task -- hs.task requires a strong reference until completion.
  if not task:start() then
    M.tasks[id] = nil
    alert("Fleet: no se pudo iniciar la tarea")
  end
end

local function catalogEntries(kind)
  local ok, catalog = pcall(hs.json.read, home .. "/.config/fleet/actions.json")
  if not ok or type(catalog) ~= "table" or catalog.version ~= 1 then return end
  local entries
  if kind == "main" or kind == "move" or kind == "resize" then entries = catalog.menu
  elseif type(catalog.media) == "table" then entries = catalog.media[kind] end
  if type(entries) ~= "table" or #entries == 0 then return end
  local result, keys = {}, {}
  for _, entry in ipairs(entries) do
    if type(entry) ~= "table" or type(entry.key) ~= "string" or type(entry.label) ~= "string"
      or type(entry.args) ~= "table" or #entry.args == 0 then return end
    local key = entry.key:lower()
    if keys[key] or key == "escape" or key == "return" then return end
    keys[key] = true
    for _, arg in ipairs(entry.args) do
      if type(arg) ~= "string" or arg:find("%z") then return end
    end
    local args = entry.args
    if kind == "move" or kind == "resize" then
      if args[1] == "focus" then
        args = { kind == "move" and "move" or "resize-step", args[2] }
      elseif kind == "move" and args[1] == "workspace" then
        args = { "move-workspace", args[2] }
      else args = nil end
    end
    if args then result[#result + 1] = { key = key, label = entry.label, args = args } end
  end
  if #result > 0 then return result end
end

function M.close()
  if M.modal then M.modal:exit(); M.modal:delete(); M.modal = nil end
  if M.canvas then M.canvas:delete(); M.canvas = nil end
  M.mode, M.target = nil, nil
  if trigger and not stopped then inspectShortcut() end
end

local titles = {
  main = "Fleet · acciones", capture = "Fleet · captura", record = "Fleet · grabación",
  combined = "Fleet · multimedia", move = "Fleet · mover ventana", resize = "Fleet · redimensionar",
}
local keyLabels = { left = "←", right = "→", up = "↑", down = "↓" }
local modeActions = {
  ["move-mode"] = "move", ["resize-mode"] = "resize", ["capture-menu"] = "capture",
  ["record-menu"] = "record", ["media-menu"] = "combined", menu = "main",
}

function M.show(kind)
  if stopped then return end
  M.close()
  generation = generation + 1
  queryPending = false
  trigger:disable()
  local entries = catalogEntries(kind)
  if not entries then alert("Fleet: catálogo de acciones ausente o inválido"); return end
  local screen = hs.screen.mainScreen()
  if not screen then alert("Fleet: no hay pantalla disponible"); return end
  local frame = screen:frame()
  local font = math.min(17, math.max(10, math.floor((frame.h - 130) / (#entries + 5) / 1.4)))
  local lines = { titles[kind], "" }
  for _, entry in ipairs(entries) do
    lines[#lines + 1] = string.format("%s   %s", keyLabels[entry.key] or entry.key:upper(), entry.label)
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = (kind == "move" or kind == "resize")
    and "Flechas repetibles · Enter/Esc: salir" or "Elige una acción · Enter/Esc: salir"
  local width, height = math.min(620, frame.w - 40), (#lines * font * 1.4 + 40)
  local canvas = hs.canvas.new({ x = frame.x + (frame.w - width) / 2,
    y = frame.y + (frame.h - height) / 2, w = width, h = height })
  if not canvas then alert("Fleet: no se pudo mostrar el menú"); return end
  canvas:appendElements(
    { type = "rectangle", action = "fill", fillColor = { white = 0.08, alpha = 0.96 },
      roundedRectRadii = { xRadius = 12, yRadius = 12 } },
    { type = "text", text = table.concat(lines, "\n"), textSize = font,
      textColor = { white = 1 }, frame = { x = 24, y = 20, w = width - 48, h = height - 40 } }
  )
  canvas:level("overlay"):clickActivating(false):show()
  M.canvas, M.mode, M.target = canvas, kind, frontApp()
  local modal = hs.hotkey.modal.new()
  M.modal = modal
  modal:bind({}, "escape", nil, M.close)
  modal:bind({}, "return", nil, M.close)
  for _, entry in ipairs(entries) do
    local function act()
      if not sameApp(M.target) then M.close(); return end
      local nextMode = modeActions[entry.args[1]]
      if nextMode then M.show(nextMode); return end
      if kind ~= "move" and kind ~= "resize" then M.close() end
      run(entry.args)
    end
    local repeatable = (kind == "move" or kind == "resize") and keyLabels[entry.key] ~= nil
    modal:bind({}, entry.key, nil, act, nil, repeatable and act or nil)
  end
  modal:enter()
end

function M.edit(action)
  if stopped then return end
  local chord, app = editChords[action], frontApp()
  if not chord or not app then alert("Fleet: acción de edición inválida"); return end
  if terminalApps[app:bundleID()] and not terminalEdits[action] then
    alert("Fleet: esa acción conserva su comportamiento nativo en terminales")
    return
  end
  M.close()
  hs.eventtap.keyStroke(chord[1], chord[2], 0, app)
end

trigger = hs.hotkey.new({ "cmd", "alt" }, "return", nil, function() inspectShortcut(true) end)
M.trigger = trigger
local urlMenus = {
  ["fleet-menu"] = "main", ["fleet-capture-menu"] = "capture", ["fleet-record-menu"] = "record",
  ["fleet-media-menu"] = "combined", ["fleet-move-mode"] = "move", ["fleet-resize-mode"] = "resize",
}
for event, kind in pairs(urlMenus) do
  hs.urlevent.bind(event, function() M.show(kind) end)
end
hs.urlevent.bind("fleet-edit", function(_, params) M.edit(params and params.action) end)
hs.urlevent.bind("fleet-lock", function()
  if stopped then return end
  M.close()
  hs.eventtap.keyStroke({ "ctrl", "cmd" }, "q", 0)
end)
watcher = hs.application.watcher.new(function(_, event)
  if event == hs.application.watcher.activated then M.close() end
end)
watcher:start()
timer = hs.timer.doEvery(3, function()
  if not M.mode and not queryPending then inspectShortcut() end
end)

function M.stop()
  stopped = true
  generation = generation + 1
  M.close()
  trigger:disable():delete()
  watcher:stop()
  timer:stop()
  -- Running media tasks retain their callbacks and are not killed on reload.
end

inspectShortcut()
return M
