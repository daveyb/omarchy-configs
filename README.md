# omarchy-configs

Overlays for the Omarchy laptop `ddbomarchy`. Stock Omarchy stays on the ISO. This tree is the delta after first boot.

Unattended install uses a `cidata` volume. The contract and the files that are safe to keep in git are under `cidata/`. Password hashes, LUKS passphrases, and Tailscale auth keys stay out.

## Layout

```
cidata/                 public unattended-install inputs
hypr/                   Hyprland overlays that differ from Omarchy defaults
omarchy/                shell.json, default agent, plugin ids, system drop-ins
systemd/user/           user units (lid-sleep-guard)
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

`capture.sh` copies Hyprland and Omarchy overlays, the lid/hibernate/wakeup drop-ins, the lid-sleep-guard user unit, git identity, XCompose, extra packages, and plugin directory names. It does not copy plugin source, `.bak` files, credential helpers, or `user_credentials.json`.

## Apply

Copy the overlays back over `~/.config`:

```
cp hypr/input.lua ~/.config/hypr/input.lua
cp hypr/monitors.lua ~/.config/hypr/monitors.lua
cp hypr/autostart.lua ~/.config/hypr/autostart.lua
cp hypr/bindings.lua ~/.config/hypr/bindings.lua
install -D hypr/scripts/xreal-laptop.sh ~/.config/hypr/scripts/xreal-laptop.sh
install -D hypr/scripts/studio-display-scale.sh ~/.config/hypr/scripts/studio-display-scale.sh
install -D hypr/scripts/lid-close.sh ~/.config/hypr/scripts/lid-close.sh
install -D hypr/scripts/lid-sleep-guard.sh ~/.config/hypr/scripts/lid-sleep-guard.sh
install -D systemd/user/lid-sleep-guard.service ~/.config/systemd/user/lid-sleep-guard.service
cp omarchy/shell.json ~/.config/omarchy/shell.json
install -D omarchy/defaults/agent ~/.config/omarchy/defaults/agent
install -d ~/.config/omarchy/system
cp -a omarchy/system/. ~/.config/omarchy/system/
cp xcompose/XCompose ~/.XCompose
```

The lid/hibernate drop-ins live in `~/.config/omarchy/system/` as the source. Install them into `/etc` with:

```
systemctl --user enable --now lid-sleep-guard.service
sudo ~/.config/omarchy/system/install-lid-chipset.sh ~/.config/omarchy/system
sudo ~/.config/omarchy/system/install-shutdown-safety.sh ~/.config/omarchy/system
```

`install-lid-chipset.sh` writes the logind hibernate policy, sleep.conf delay, Studio Display wakeup udev rules, lid-panel-off (including the initramfs hook), and the S4 wake policy. It does not restart `systemd-logind`. Restarting logind on this XPS breaks the Hyprland Wayland socket. `HandleLidSwitch=hibernate` applies on the next logind start, so reboot once. Live lid-close already hibernates from the Hyprland bind.

`install-studio-display-wakeup.sh` is the narrower re-apply for the logind/sleep drop-ins and display udev rules only.

Clone the plugins named in `omarchy/plugins.txt` with `omarchy plugin clone`. Install extras with `omarchy pkg add` and `omarchy pkg aur add` as needed. Reload Hyprland with `hyprctl reload`.

## What changed on this host

- Caps Lock is a normal toggle on external keyboards. The laptop key stays Compose.
- Keyboard repeat is 25/400. Touchpad scroll factor is 0.5.
- Monitors: laptop at 1.25x, Apple Studio Display at 3.2x. Unplug restores 1.25x on the remaining display. HP E243 sits above the laptop. XREAL One Pro is 1.6x with the laptop panel off while the glasses are connected.
- Lid close hibernates on battery and on AC unless an external display is connected. This XPS only has s2idle, which still draws about 2W in a bag. Clamshell on the Studio Display stays awake via docked-ignore plus a userspace lid-switch inhibitor. AC is not treated as docked.
- Closed lid blanks the laptop panel (session, systemd-sleep, Plymouth/LUKS). Initramfs powers off if the lid stays shut 10s at the passphrase prompt. USB/Thunderbolt S4 wake is off unless a display is actually plugged in. The Alienware keyboard on the Studio Display hub can wake when that display is present.
- Bar: 12-hour clock, Tailscale, Grokbar, OmaProton VPN.
- Default agent is `grok`.
- Extra packages: Calibre, draw.io, GitHub Copilot CLI, grok-bot, Pocket Casts, Proton VPN CLI, rclone, Tailscale, Telegram, voxtype, Zed.
