-- Steam games keep their own class. Dead Cells is "deadcells", and a gamepad
-- never counts as activity. The stock rule only matches class "steam", and only
-- while that window is fullscreen. "focus" drops as soon as the overlay, a
-- launcher, or Big Picture takes the keyboard, so the screensaver still starts
-- mid-game. Hold idle off for the whole life of the game window.
-- Numeric classes are Steam games. steam_app_battlenet is the launcher.

o.window({ class = "^steam_app_[0-9]" }, { idle_inhibit = "always" })
o.window({ tag = "steam-game" }, { idle_inhibit = "always" })

local function has_steam_app_id(pid)
  local f = io.open("/proc/" .. tostring(pid) .. "/environ", "rb")
  if not f then
    return false
  end
  local data = f:read("*a")
  f:close()
  if not data or data == "" then
    return false
  end
  if data:sub(1, 11) == "SteamAppId=" then
    return true
  end
  return data:find("\0SteamAppId=", 1, true) ~= nil
end

local function parent_pid(pid)
  local f = io.open("/proc/" .. tostring(pid) .. "/stat", "r")
  if not f then
    return nil
  end
  local line = f:read("*a")
  f:close()
  if not line then
    return nil
  end
  local rest = line:match("%) (.*)$")
  if not rest then
    return nil
  end
  return tonumber(rest:match("^%S+%s+(%d+)"))
end

local function ancestry_has_steam_app(pid)
  local seen = {}
  for _ = 1, 24 do
    if not pid or pid <= 1 or seen[pid] then
      return false
    end
    seen[pid] = true
    if has_steam_app_id(pid) then
      return true
    end
    pid = parent_pid(pid)
  end
  return false
end

local function comm_of(pid)
  local f = io.open("/proc/" .. tostring(pid) .. "/comm", "r")
  if not f then
    return ""
  end
  local comm = f:read("*l") or ""
  f:close()
  return comm
end

local function class_owned_by_steam_game(class_name)
  local handle = io.popen("ls -d /proc/[0-9]* 2>/dev/null")
  if not handle then
    return false
  end
  local found = false
  for path in handle:lines() do
    local pid = tonumber(path:match("(%d+)$"))
    if pid and pid > 1 and comm_of(pid) == class_name and has_steam_app_id(pid) then
      found = true
      break
    end
  end
  handle:close()
  return found
end

local function launched_by_steam(w)
  if w == nil then
    return false
  end
  local class_name = w.class or ""
  if class_name == "steam" or class_name == "steamwebhelper" then
    return false
  end
  if w.pid and w.pid > 1 and ancestry_has_steam_app(w.pid) then
    return true
  end
  if not w.xwayland or class_name == "" then
    return false
  end
  return class_owned_by_steam_game(class_name)
end

local function inhibit(w)
  if not launched_by_steam(w) then
    return
  end
  hl.dispatch(hl.dsp.window.tag({ tag = "+steam-game", window = w }))
  hl.dispatch(hl.dsp.window.set_prop({ prop = "idle_inhibit", value = "always", window = w }))
end

local function consider(w)
  local ok, err = pcall(inhibit, w)
  if not ok then
    print("steam-idle: " .. tostring(err))
  end
end

local function consider_open()
  local windows = hl.get_windows()
  if not windows then
    return
  end
  for _, w in ipairs(windows) do
    consider(w)
  end
end

hl.on("window.open", consider)
hl.on("config.reloaded", consider_open)
consider_open()
