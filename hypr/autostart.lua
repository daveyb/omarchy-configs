-- Extra autostart processes.
-- o.launch_on_start("my-service")

-- Keep the laptop panel in sync with XREAL glasses (DRM poll + hypr events).
o.launch_on_start(os.getenv("HOME") .. "/.config/hypr/scripts/xreal-laptop.sh")

-- Restore 1.25x after the Apple Studio Display unplugs (Hyprland keeps 3.2x).
o.launch_on_start(os.getenv("HOME") .. "/.config/hypr/scripts/studio-display-scale.sh")
