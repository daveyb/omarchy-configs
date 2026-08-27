# omarchy-configs

Overlays for the Omarchy laptop `ddbomarchy`. Stock Omarchy stays on the ISO. This tree is the delta after first boot.

Unattended install uses a `cidata` volume. The contract and the files that are safe to keep in git are under `cidata/`. Password hashes, LUKS passphrases, and Tailscale auth keys stay out.

## Layout

```
cidata/                 public unattended-install inputs
hypr/                   Hyprland overlays that differ from Omarchy defaults
omarchy/                shell.json, default agent, plugin ids
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

`capture.sh` copies Hyprland and Omarchy overlays, git identity, XCompose, extra packages, and plugin directory names. It does not copy plugin source, `.bak` files, credential helpers, or `user_credentials.json`.

## Apply

Copy the overlays back over `~/.config`:

```
cp hypr/input.lua ~/.config/hypr/input.lua
cp hypr/monitors.lua ~/.config/hypr/monitors.lua
cp hypr/autostart.lua ~/.config/hypr/autostart.lua
install -D hypr/scripts/xreal-laptop.sh ~/.config/hypr/scripts/xreal-laptop.sh
cp omarchy/shell.json ~/.config/omarchy/shell.json
install -D omarchy/defaults/agent ~/.config/omarchy/defaults/agent
cp xcompose/XCompose ~/.XCompose
```

Clone the plugins named in `omarchy/plugins.txt` with `omarchy plugin clone`. Install extras with `omarchy pkg add` and `omarchy pkg aur add` as needed. Reload Hyprland with `hyprctl reload`.

## What changed on this host

- Caps Lock is a normal toggle on external keyboards. The laptop key stays Compose.
- Keyboard repeat is 25/400. Touchpad scroll factor is 0.5.
- Monitors: laptop at 3.2x, Apple Studio Display at 3.2x, HP E243 above the laptop, XREAL One Pro at 1.6x with the laptop panel off while the glasses are connected.
- Bar: 12-hour clock, Tailscale, Grokbar, OmaProton VPN.
- Default agent is `grok`.
- Extra packages: Calibre, draw.io, GitHub Copilot CLI, grok-bot, Pocket Casts, Proton VPN CLI, rclone, Tailscale, Telegram, voxtype, Zed.
