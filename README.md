# omarchy-configs

Overlays for the Omarchy laptop `ddbomarchy`. Stock Omarchy stays on the ISO. This tree is the delta after first boot.

Unattended install uses a `cidata` volume. The contract and the files that are safe to keep in git are under `cidata/`. Password hashes, LUKS passphrases, and Tailscale auth keys stay out.

## Layout

```
cidata/                 public unattended-install inputs
hypr/                   Hyprland overlays that differ from Omarchy defaults
local-bin/              helper scripts owned by the user units
omarchy/                shell.json, default agent/dictation, plugin ids, system drop-ins
systemd/user/           user units (lid-awake, bose-a2dp-retry, voxtype)
git/config              user.name and user.email only
xcompose/XCompose       compose sequences for name and email
packages/extras.txt     explicit packages not in the Omarchy install lists
scripts/capture.sh      copy live overlays into this tree
scripts/scan-secrets.sh fail if a secret landed here
```

## Capture

From a configured `ddbomarchy`:

```
./scripts/capture.sh
./scripts/scan-secrets.sh
```

`capture.sh` copies Hyprland and Omarchy overlays, the lid-awake/bose/voxtype user units, the bose helper script, the lid/hibernate/wakeup drop-in sources, git identity, XCompose, extra packages, and plugin directory names. It does not copy plugin source, `.bak` files, credential helpers, or `user_credentials.json`.

## Apply

Copy the overlays back over `~/.config`:

```
cp hypr/input.lua ~/.config/hypr/input.lua
cp hypr/monitors.lua ~/.config/hypr/monitors.lua
cp hypr/autostart.lua ~/.config/hypr/autostart.lua
cp hypr/bindings.lua ~/.config/hypr/bindings.lua
cp hypr/hyprland.lua ~/.config/hypr/hyprland.lua
cp hypr/steam-idle.lua ~/.config/hypr/steam-idle.lua
cp hypr/steam-quit.lua ~/.config/hypr/steam-quit.lua
install -D hypr/scripts/xreal-laptop.sh ~/.config/hypr/scripts/xreal-laptop.sh
install -D hypr/scripts/studio-display-scale.sh ~/.config/hypr/scripts/studio-display-scale.sh
install -D hypr/scripts/studio-display-only.sh ~/.config/hypr/scripts/studio-display-only.sh
install -D hypr/scripts/lid-awake.sh ~/.config/hypr/scripts/lid-awake.sh
install -D hypr/scripts/steam-quit-on-close.sh ~/.config/hypr/scripts/steam-quit-on-close.sh
install -D systemd/user/lid-awake.service ~/.config/systemd/user/lid-awake.service
install -D systemd/user/bose-a2dp-retry.service ~/.config/systemd/user/bose-a2dp-retry.service
install -D systemd/user/voxtype.service ~/.config/systemd/user/voxtype.service
install -D local-bin/bose-a2dp-retry ~/.local/bin/bose-a2dp-retry
cp omarchy/shell.json ~/.config/omarchy/shell.json
install -D omarchy/defaults/agent ~/.config/omarchy/defaults/agent
install -D omarchy/defaults/dictation ~/.config/omarchy/defaults/dictation
install -d ~/.config/omarchy/system
cp -a omarchy/system/. ~/.config/omarchy/system/
cp xcompose/XCompose ~/.XCompose
```

Enable the user units with:

```
systemctl --user enable --now lid-awake.service bose-a2dp-retry.service voxtype.service
```

Lid close follows the stock suspend path. `lid-awake.service` holds a `handle-lid-switch` block inhibitor while an external monitor is connected or Pocket Casts is playing, and the Hyprland lid binds run `lid-awake.sh` for lock/clamshell handling (dark panel while audio plays).

The lid/hibernate drop-in sources still live in `~/.config/omarchy/system/` but are no longer installed in `/etc` on this host. Installing them would switch lid close back to hibernate:

```
sudo ~/.config/omarchy/system/install-lid-chipset.sh ~/.config/omarchy/system
sudo ~/.config/omarchy/system/install-shutdown-safety.sh ~/.config/omarchy/system
```

`install-lid-chipset.sh` writes the logind hibernate policy, sleep.conf delay, Studio Display wakeup udev rules, lid-panel-off (including the initramfs hook), and the S4 wake policy. It does not restart `systemd-logind`. Restarting logind on this XPS breaks the Hyprland Wayland socket. `HandleLidSwitch=hibernate` applies on the next logind start, so reboot once.

`install-studio-display-wakeup.sh` is the narrower re-apply for the logind/sleep drop-ins and display udev rules only.

Add the third-party plugins named in `omarchy/plugins.txt`, then copy `omarchy/shell.json` so the bar matches:

```
omarchy plugin add https://github.com/davefano/omarchy-trackpad-plus.git --enable
omarchy plugin add https://github.com/nixfred/blip.git --enable
omarchy plugin add https://github.com/grichard99/omaproton-vpn --enable
omarchy plugin add https://github.com/gfhdhytghd/hymission.git --enable
```

Blip still needs `blip-setup` on this host (Mac SSH and `~/.config/blip/bridge.conf`). That stays off this tree. Install extras with `omarchy pkg add` and `omarchy pkg aur add` as needed. Reload Hyprland with `hyprctl reload`. Note: `omarchy/shell.json` still references the removed `rlimberger.grokbar-omarchy` bar widget, matching the host.

## What changed on this host

- Caps Lock is a normal toggle on external keyboards. The laptop key stays Compose.
- Keyboard repeat is 25/400. Touchpad scroll factor is 0.5.
- Monitors: laptop at 1.25x. The Apple Studio Display is the sole screen at highres 1x while connected (`studio-display-only.sh` turns the laptop panel off once the display shows a picture). Unplug restores 1.25x on the remaining display. HP E243 sits above the laptop. XREAL One Pro is 1.6x with the laptop panel off while the glasses are connected (it defers while studio-only owns the panel).
- Lid close follows the stock suspend path. `lid-awake` holds a lid-switch inhibitor while an external display is connected or Pocket Casts (Chromium PWA) is playing, with 15s tails against connector blips. A playback lid-close darkens the panel instead of locking so audio keeps playing.
- The hibernate drop-in sources in `omarchy/system/` are retained but no longer installed in `/etc`: no logind hibernate policy, S4 wake policy, or initramfs panel-off on this host.
- Bar: `ddd d MMM h:mm AP` clock with a life-expectancy countdown, indicators plus elsewhen/weather/system-update in centerBegin/centerEnd, tray and keyboard-layout first on the right, then Trackpad Plus, Blip, Tailscale, agents, bluetooth, network, OmaProton VPN, audio, monitor, power.
- Hymission overview service is enabled. 4-finger horizontal swipes switch workspaces and 4-finger vertical toggles the overview in `hypr/input.lua`.
- Default agent is `muse`. Default dictation backend is `voxtype` (SUPER+CTRL+X toggle and F9 push-to-talk kept from before the new defaults).
- Steam games hold idle off for the game window's life; closing the main Steam window quits the client unless a game is running.
- Bluetooth: `bose-a2dp-retry` reconnects headsets when BlueZ 5.87's first A2DP connection fails with device-busy.
- Extra packages: clang/LLVM/CMake/Ninja toolchain, draw.io, grok-bot, Hermes, Kdenlive, lazydocker, 32-bit Intel Vulkan (Steam), OBS Studio, owe-lockfeed, Proton VPN CLI, Spotify, Steam, Tailscale, Telegram, voxtype, Xournal++.
