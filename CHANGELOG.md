# Changelog

All notable changes to this overlay tree are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[1.0.1]: https://github.com/daveyb/omarchy-configs/releases/tag/v1.0.1
[1.0.0]: https://github.com/daveyb/omarchy-configs/releases/tag/v1.0.0
