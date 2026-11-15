-- Extra autostart processes.
-- o.launch_on_start("my-service")

-- Keep the laptop panel in sync with XREAL glasses (DRM poll + hypr events).
o.launch_on_start(os.getenv("HOME") .. "/.config/hypr/scripts/xreal-laptop.sh")

-- Restore 1.25x after the Apple Studio Display unplugs (Hyprland keeps its scale).
o.launch_on_start(os.getenv("HOME") .. "/.config/hypr/scripts/studio-display-scale.sh")

-- Studio Display is the only screen, at full resolution, while it is connected.
o.launch_on_start(os.getenv("HOME") .. "/.config/hypr/scripts/studio-display-only.sh")
