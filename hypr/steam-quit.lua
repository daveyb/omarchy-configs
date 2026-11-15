-- Closing Steam only destroys the window. The client keeps running and the
-- status bar keeps the tray icon. Quit the client when the main window
-- closes. Small "Steam" windows are the startup splash, not a user close.
-- Games are left alone by the script this hands off to.

local script = (os.getenv("HOME") or "") .. "/.config/hypr/scripts/steam-quit-on-close.sh"

local function is_main_steam(w)
  if w == nil then
    return false
  end

  local class_name = string.lower(w.class or "")
  local initial = string.lower(w.initialClass or "")
  if class_name ~= "steam" and initial ~= "steam" then
    return false
  end

  local title = w.title or ""
  local initial_title = w.initialTitle or ""
  if title == "Sign in to Steam" or initial_title == "Sign in to Steam" then
    return true
  end
  if title ~= "Steam" and initial_title ~= "Steam" then
    return false
  end

  -- The startup splash is also titled "Steam", and it is small.
  local size = w.size
  if size ~= nil and size.x ~= nil and size.y ~= nil then
    if size.x < 800 or size.y < 500 then
      return false
    end
  end

  return true
end

hl.on("window.close", function(w)
  if not is_main_steam(w) then
    return
  end

  hl.exec_cmd(script .. " " .. o.shell_quote(w.address or ""))
end)
