-- Behavioral contract, using no native Hammerspoon, keyboard, or screen APIs.
local modulePath, fixturePath = arg[1], arg[2]
local catalog = dofile(fixturePath)
local current, pending, urls, strokes, tasks, alerts = nil, {}, {}, {}, {}, {}
local watcher, timer, globalHotkey
local executableAvailable, failTaskStart = true, false
local tests = 0
local function check(condition, message)
  assert(condition, message)
  tests = tests + 1
end
local function app(bundle, pid)
  local value = { bundle = bundle, process = pid, menus = {} }
  function value:bundleID() return self.bundle end
  function value:pid() return self.process end
  function value:getMenuItems(callback)
    assert(type(callback) == "function", "menu inspection must be asynchronous")
    if self.failMenus then error("accessibility unavailable") end
    pending[#pending + 1] = { app = self, callback = callback }
    return self
  end
  return value
end
local function flush()
  local queue = pending
  pending = {}
  for _, request in ipairs(queue) do request.callback(request.app.menus) end
end
local function changeApp(value)
  current = value
  watcher.callback(value.bundle, 1, value)
end
local function lastTask()
  return tasks[#tasks]
end
local function count(tableValue)
  local n = 0
  for _ in pairs(tableValue) do n = n + 1 end
  return n
end

hs = {
  alert = { show = function(message) alerts[#alerts + 1] = message end },
  fs = { attributes = function() return executableAvailable and { mode = "file" } or nil end },
  json = { read = function() return catalog end },
  screen = { mainScreen = function()
    return { frame = function() return { x = 0, y = 0, w = 1440, h = 900 } end }
  end },
  eventtap = { keyStroke = function(mods, key, delay, target)
    strokes[#strokes + 1] = { mods = mods, key = key, app = target }
  end },
  urlevent = { bind = function(event, callback) urls[event] = callback end },
  application = { frontmostApplication = function() return current end, watcher = { activated = 1 } },
  timer = { doEvery = function(seconds, callback)
    timer = { callback = callback, stop = function(self) self.stopped = true end }
    return timer
  end },
  canvas = { new = function(frame)
    local canvas = { frame = frame }
    function canvas:appendElements(...) self.elements = { ... }; return self end
    function canvas:level(value) self.levelValue = value; return self end
    function canvas:clickActivating(value) self.activating = value; return self end
    function canvas:show() self.showing = true; return self end
    function canvas:delete() self.deleted = true end
    return canvas
  end },
  hotkey = { modal = {} },
  task = { new = function(path, callback, stream, args)
    check(stream == nil and path:match("/fleet%-ui$") ~= nil, "tasks invoke the CLI directly")
    local task = { callback = callback, args = args }
    function task:start() self.started = not failTaskStart; return self.started and self or nil end
    function task:finish(code, stdout, stderr) self.callback(code or 0, stdout or "", stderr or "") end
    tasks[#tasks + 1] = task
    return task
  end },
}
function hs.application.watcher.new(callback)
  watcher = { callback = callback }
  function watcher:start() self.started = true end
  function watcher:stop() self.stopped = true end
  return watcher
end
function hs.hotkey.new(mods, key, message, pressed)
  check(table.concat(mods, "+") == "cmd+alt" and key == "return", "only Cmd+Alt+Enter is global")
  globalHotkey = { callback = pressed, enabled = false }
  function globalHotkey:enable() self.enabled = true; return self end
  function globalHotkey:disable() self.enabled = false; return self end
  function globalHotkey:delete() self.deleted = true; return self end
  return globalHotkey
end
function hs.hotkey.modal.new()
  local modal = { bindings = {} }
  function modal:bind(mods, key, message, pressed, released, repeated)
    check(#mods == 0, "modal does not remap native Cmd or Ctrl chords")
    assert(not self.bindings[key], "duplicate modal key")
    self.bindings[key] = { pressed = pressed, repeated = repeated }
    return self
  end
  function modal:enter() self.entered = true end
  function modal:exit() self.exited = true end
  function modal:delete() self.deleted = true end
  return modal
end

local known = app("org.dbgate", 10)
current = known
local fleet = dofile(modulePath)
check(not globalHotkey.enabled and #pending == 1, "initial trigger waits for inspection")
flush()
check(globalHotkey.enabled, "known application with inspected menus is eligible")

for _, special in ipairs({ 4, 11, 12, 13, "\r", "\n", "return", "enter", "↩" }) do
  local glyph = type(special) == "number" and special or ""
  local char = type(special) == "string" and special or ""
  known.menus = { { { AXEnabled = false, AXMenuItemCmdModifiers = { "cmd", "alt" },
    AXMenuItemCmdChar = char, AXMenuItemCmdGlyph = glyph } } }
  timer.callback(); flush()
  check(not globalHotkey.enabled, "native Cmd+Alt+Enter remains owned by the application")
end
known.menus = {}
timer.callback(); flush()
check(globalHotkey.enabled, "trigger can recover after a menu changes")
globalHotkey.callback()
check(not globalHotkey.enabled, "keypress rechecks current menu before opening")
flush()
check(fleet.mode == "main" and fleet.canvas.showing and fleet.modal.entered, "main menu is visible")
check(fleet.canvas.activating == false, "overlay preserves foreground application")
local oldCanvas, oldModal = fleet.canvas, fleet.modal
fleet.modal.bindings.t.pressed()
check(fleet.mode == nil and oldCanvas.deleted and oldModal.deleted, "ordinary action closes overlay and modal")
check(lastTask().args[1] == "terminal" and lastTask().started, "terminal action uses the catalog")
check(count(fleet.tasks) == 1, "task is strongly retained")
lastTask():finish()
check(count(fleet.tasks) == 0, "completed task is released")
flush()

-- A newly exposed shortcut gets the original key event, not a Fleet menu.
known.menus = { { AXMenuItemCmdModifiers = { "command", "option" }, AXMenuItemCmdChar = "\r" } }
globalHotkey.callback(); flush()
check(fleet.mode == nil and not globalHotkey.enabled, "new native conflict does not open menu")
check(strokes[#strokes].key == "return" and strokes[#strokes].app == known, "consumed chord is forwarded natively")
known.menus = {}
timer.callback()
local unknown = app("example.uninspected", 20)
changeApp(unknown); flush()
check(not globalHotkey.enabled, "late inspection cannot enable trigger for an unknown app")
check(#pending == 0, "unknown apps are not inspected or intercepted")
local code = app("com.microsoft.VSCode", 30)
changeApp(code); flush()
check(not globalHotkey.enabled and #pending == 0, "VSCode hidden native Replace All shortcut is never intercepted")
urls["fleet-menu"]()
check(fleet.mode == "main", "VSCode can open the explicit command menu")
fleet.close(); flush()
changeApp(known); flush()
known.menus = nil
timer.callback(); flush()
check(not globalHotkey.enabled, "missing menu result is conservative")
known.failMenus = true
timer.callback()
check(not globalHotkey.enabled, "inspection exception is conservative")
known.failMenus, known.menus = false, {}
timer.callback(); flush()
known.failMenus = true
local failedStrokeCount = #strokes
globalHotkey.callback()
check(#strokes == failedStrokeCount + 1 and strokes[#strokes].app == known, "keypress inspection exception forwards native chord")
known.failMenus = false
timer.callback(); flush()

urls["fleet-move-mode"]()
check(fleet.mode == "move" and fleet.canvas.showing, "move URL opens a visible mode")
fleet.modal.bindings.left.pressed()
fleet.modal.bindings.left.repeated()
check(lastTask().args[1] == "move" and lastTask().args[2] == "left" and fleet.mode == "move", "move arrows repeat and keep mode")
fleet.modal.bindings["0"].pressed()
check(lastTask().args[1] == "move-workspace" and lastTask().args[2] == "10", "zero moves to workspace 10")
fleet.modal.bindings["return"].pressed()
check(fleet.mode == nil, "Enter leaves move mode")
urls["fleet-resize-mode"]()
fleet.modal.bindings.up.repeated()
check(lastTask().args[1] == "resize-step" and lastTask().args[2] == "up", "resize repeats the CLI step")
check(fleet.modal.bindings["0"] == nil, "resize does not bind workspace numbers")
fleet.modal.bindings.escape.pressed()
check(fleet.mode == nil, "Esc leaves resize mode")

for event, kind in pairs({ ["fleet-capture-menu"] = "capture", ["fleet-record-menu"] = "record",
  ["fleet-media-menu"] = "combined", ["fleet-menu"] = "main" }) do
  urls[event]()
  check(fleet.mode == kind and fleet.canvas.showing, event .. " shows its catalog")
end
urls["fleet-media-menu"]()
fleet.modal.bindings.g.pressed()
check(fleet.mode == "record", "combined media routes to record menu")
urls["fleet-menu"]()
fleet.modal.bindings.c.pressed()
check(fleet.mode == "capture", "main capture action opens capture menu")
fleet.modal.bindings["3"].pressed()
check(table.concat(lastTask().args, " ") == "screenshot screen --file auto", "capture preserves target and destination args")
urls["fleet-record-menu"]()
fleet.modal.bindings.e.pressed()
lastTask():finish(0, '{"recording":true}')
check(alerts[#alerts] == '{"recording":true}', "record status is displayed")

-- No shell is involved, even when a trusted catalog argument has shell syntax.
local ordinary = catalog.menu[1]
local originalArgs = ordinary.args
ordinary.args = { "test-action", "$(touch should-not-exist);'literal'" }
urls["fleet-menu"]()
fleet.modal.bindings[ordinary.key:lower()].pressed()
check(lastTask().args[2] == "$(touch should-not-exist);'literal'", "arguments remain literal")
ordinary.args = originalArgs
failTaskStart = true
local before = count(fleet.tasks)
urls["fleet-menu"](); fleet.modal.bindings.t.pressed()
check(count(fleet.tasks) == before, "failed task start does not leak a retained task")
failTaskStart = false
executableAvailable = false
local taskCount = #tasks
urls["fleet-menu"](); fleet.modal.bindings.t.pressed()
check(#tasks == taskCount, "missing CLI fails without starting a shell")
executableAvailable = true

local terminal = app("com.apple.Terminal", 30)
changeApp(terminal); flush()
local strokeCount = #strokes
for _, action in ipairs({ "undo", "redo", "cut", "select-all", "save", "find", "open", "new", "location", "reload" }) do
  urls["fleet-edit"]("fleet-edit", { action = action })
end
check(#strokes == strokeCount, "terminal editing exceptions keep native behavior")
for _, action in ipairs({ "copy", "paste", "close", "new-tab", "quit" }) do
  urls["fleet-edit"]("fleet-edit", { action = action })
end
check(#strokes == strokeCount + 5 and strokes[#strokes].key == "q", "terminal allowed actions include graceful Cmd+Q")
check(table.concat(strokes[#strokes].mods, "+") == "cmd", "quit uses normal application command")
changeApp(known); flush()
for _, action in ipairs({ "copy", "paste", "cut", "undo", "redo", "select-all", "save", "find", "open", "new", "new-tab", "close", "quit", "location", "reload" }) do
  urls["fleet-edit"]("fleet-edit", { action = action })
end
check(strokes[#strokes].key == "r", "all supported native edit chords are available")
strokeCount = #strokes
urls["fleet-edit"]("fleet-edit", { action = "invalid" })
check(#strokes == strokeCount, "invalid URL action is rejected")
urls["fleet-lock"]()
check(strokes[#strokes].key == "q" and table.concat(strokes[#strokes].mods, "+") == "ctrl+cmd", "lock uses native system chord")

urls["fleet-menu"]()
local active = fleet.modal
changeApp(unknown)
check(fleet.mode == nil and active.deleted, "switching applications exits visible mode")
local savedCatalog = catalog
catalog = { version = 2, menu = {} }
urls["fleet-menu"]()
check(fleet.mode == nil, "unsupported catalog fails without interception")
catalog = savedCatalog
fleet.stop()
check(globalHotkey.deleted and watcher.stopped and timer.stopped, "module cleanup disables its resources")
flush()
check(not globalHotkey.enabled, "late callback after stop cannot enable a shortcut")
urls["fleet-menu"]()
check(fleet.mode == nil, "stopped URL handler cannot create new interception")
print("Fleet Darwin contract passed: " .. tests .. " assertions (mocked hs; no native UI)")
