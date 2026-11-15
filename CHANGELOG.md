# Changelog

All notable changes to this overlay tree are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-11-14

Live-host resync. Lid close follows the stock suspend path with a
stay-awake inhibitor, the Studio Display is the sole screen while
connected, and Steam, Hymission, dictation, and Bluetooth-retry overlays
are captured.

### Added

- `hypr/scripts/lid-awake.sh` and `systemd/user/lid-awake.service`: hold a
  `handle-lid-switch` block inhibitor while an external monitor is
  connected or Pocket Casts (now a Chromium PWA) is playing, with 15s
  tails against USB-C blips. A playback lid-close darkens the panel
  instead of locking so audio keeps playing.
- `hypr/scripts/studio-display-only.sh`: while the Studio Display shows a
  picture it is the only screen at highres 1x (DRM EDID decides, so a
  stale Hyprland head cannot keep the laptop panel off).
- Steam overlays: `hypr/steam-idle.lua` holds idle off for the whole life
  of a game window (SteamAppId ancestry, not just fullscreen `steam`
  class), `hypr/steam-quit.lua` plus
  `hypr/scripts/steam-quit-on-close.sh` quit the client when the main
  window closes unless a game runs, and `hypr/hyprland.lua` requires both.
- Hymission overview service (`io.github.gfhdhytghd.hymission`): 4-finger
  horizontal swipes switch workspaces and 4-finger vertical toggles the
  overview (Trackpad Plus v8 settings in `hypr/input.lua`).
- `omarchy/defaults/dictation` (`voxtype`) with SUPER+CTRL+X toggle and F9
  push-to-talk bindings kept from before the new defaults.
- `systemd/user/bose-a2dp-retry.service` plus `local-bin/bose-a2dp-retry`:
  reconnect headsets when BlueZ 5.87's first A2DP connection fails with
  device-busy.
- `systemd/user/voxtype.service` for the push-to-talk daemon.
- Bar otherwise: elsewhen world cities (New York, London, Dubai, Tokyo,
  Los Angeles), keyboard-layout moved to the right, indicators and
  weather/system-update in centerBegin/centerEnd.
- Extra packages: clang, cmake, hermes-desktop, kdenlive, lazydocker,
  lib32-vulkan-intel, llvm, ninja, obs-studio, owe-lockfeed, spotify,
  steam, xournalpp.

### Changed

- Default agent is `muse` (was `grok`).
- Studio Display monitor rule is highres at 1x sole-screen (was preferred
  at 3.2x secondary). `xreal-laptop.sh` defers while studio-only owns the
  laptop panel.
- Clock format is `ddd d MMM h:mm AP` with `birthYear` 1982 and
  `lifeExpectancy` 92; `centerAnchor` is gone.
- `capture.sh` tracks the current host file set (lid-awake, studio-only,
  steam, dictation, bose/voxtype units, local-bin).

### Removed

- `hypr/scripts/lid-close.sh`, `hypr/scripts/lid-sleep-guard.sh`, and
  `systemd/user/lid-sleep-guard.service`: hibernate-on-lid-close is no
  longer the live path. The `omarchy/system/` drop-in sources are
  retained but not installed in `/etc` on this host.
- `rlimberger.grokbar-omarchy` plugin directory. `shell.json` still
  references its bar widget, matching the host.
- Extra packages: calibre, github-copilot-cli, pocket-casts-linux (now a
  Chromium PWA), rclone, zed.

### Fixed

- `git/config` and `cidata/user_email_address.txt` carry the full
  `user.email` with `@`; the initial capture dropped it.

## [1.0.1] - 2026-09-20

### Added

- Third-party bar plugins installed on 2026-09-19: Trackpad Plus
  (`davefano.trackpad-plus`) and Blip (`nixfred.blip`). Both sit on the right
  of the bar after the tray. Trackpad Plus's 4-finger workspace swipe is in
  `hypr/input.lua`. Plugin source, Blip's Mac SSH setup, and
  `~/.config/blip/bridge.conf` stay off this tree.

## [1.0.0] - 2026-09-13

First tagged release of the `ddbomarchy` overlay tree. The overlays already on
`main` (Hyprland input/monitors/autostart, packages, cidata contract) plus the
lid/hibernate stack captured from this host.

### Added

- Lid close hibernates on battery and on AC when no external display is
  connected. This XPS 13 9305 only exposes s2idle, which still draws about 2W
  and runs warm in a closed bag.
- Clamshell on the Studio Display stays awake with `HandleLidSwitchDocked=ignore`
  plus a userspace lid-switch inhibitor while an external display is connected.
  A charger is not treated as docked.
- Hyprland `switch:on:Lid Switch` runs `hypr/scripts/lid-close.sh`, which locks,
  reconciles displays, and hibernates if the lid is shut with no external
  monitor.
- `systemd/user/lid-sleep-guard.service` holds the clamshell inhibitor, waits
  out Thunderbolt blips, and hibernates if the lid stays shut with no external
  display for 15s.
- Studio Display Thunderbolt/USB wakeup rules so the Alienware keyboard on the
  display hub can wake the machine when that display is present. Linux root-hub
  wakeup (`idVendor` 1d6b) stays off so a USB-C jostle in a bag cannot resume
  S4 to the LUKS prompt.
- ACPI/USB/Thunderbolt S4 wake is disabled unless an external display is
  actually connected.
- Closed-lid panel blanking for sleep, hibernate, systemd-backlight restore,
  and Plymouth/LUKS in the initramfs. If the lid stays shut for 10s at the
  LUKS prompt, the initramfs powers off and leaves the hibernation image on
  disk.
- Hibernate freezes user sessions so Hyprland cannot relight a closed lid while
  writing the image.
- `HibernateDelaySec=2min` is only a backstop for leftover
  suspend-then-hibernate callers. Lid close hibernates immediately.
- Shutdown-safety drop-ins: skip reboot-force when TPM PCR extend fails during
  poweroff, and blank the panel in systemd-shutdown.
- `capture.sh` copies the lid/hibernate drop-ins, Hyprland lid scripts,
  `bindings.lua`, and the lid-sleep-guard user unit.

[1.1.0]: https://github.com/daveyb/omarchy-configs/releases/tag/v1.1.0
[1.0.1]: https://github.com/daveyb/omarchy-configs/releases/tag/v1.0.1
[1.0.0]: https://github.com/daveyb/omarchy-configs/releases/tag/v1.0.0
