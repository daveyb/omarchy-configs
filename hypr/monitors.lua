-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local function xreal_connected()
  for _, monitor in ipairs(hl.get_monitors()) do
    local desc = string.lower(tostring(monitor.description or ""))
    if desc:find("xreal", 1, true) or desc:find("nreal", 1, true) then
      return true
    end
  end

  return false
end

-- Laptop default. XREAL glasses use 1.6 below (same preset as the Omarchy scale selector).
local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1.25

hl.env("GDK_SCALE", xreal_connected() and "2" or tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })
hl.monitor({
  output = "desc:Nreal XREAL One Pro",
  mode = "preferred",
  position = "auto",
  scale = 1.6,
})

-- Apple Studio Display: match by description so DP/HDMI/dock port changes
-- still get 3.2x on plug-in (5120x2880 -> 1600x900 logical).
hl.monitor({
  output = "desc:Apple Computer Inc StudioDisplay 0x3BFFBA20",
  mode = "preferred",
  position = "0x0",
  scale = 3.2,
})

-- HP E243 on top, laptop panel directly below. auto-down keeps the laptop
-- at 0x0 when the HP is unplugged (first monitor ignores the direction).
hl.monitor({
  output = "desc:HP Inc. HP E243 CNC8520CNP",
  mode = "preferred",
  position = "0x0",
  scale = omarchy_monitor_scale,
})
hl.monitor({
  output = "eDP-1",
  mode = "preferred",
  position = "auto-down",
  scale = omarchy_monitor_scale,
})

-- XREAL glasses: laptop panel off while connected, on again when unplugged.
-- ~/.config/hypr/scripts/xreal-laptop.sh owns the toggle; these events just
-- wake it so we don't wait for the next poll.
local xreal_laptop = os.getenv("HOME") .. "/.config/hypr/scripts/xreal-laptop.sh --once"
local studio_scale = os.getenv("HOME") .. "/.config/hypr/scripts/studio-display-scale.sh --once"

hl.on("monitor.added", function()
  hl.exec_cmd(xreal_laptop)
  hl.exec_cmd(studio_scale)
end)
hl.on("monitor.removed", function()
  hl.exec_cmd(xreal_laptop)
  hl.exec_cmd(studio_scale)
end)
hl.on("hyprland.start", function()
  hl.exec_cmd(xreal_laptop)
  hl.exec_cmd(studio_scale)
end)

-- Configure a specific monitor.
-- hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x0", scale = 1 })

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })
