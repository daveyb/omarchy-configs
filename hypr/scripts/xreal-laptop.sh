#!/bin/bash

# Turn the laptop panel off while XREAL glasses are plugged in, and back on
# when they disappear. DRM/EDID is the source of truth so a stale Hyprland
# head or FALLBACK output cannot keep the laptop disabled after unplug.

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy"
CONNECTED_FLAG="$STATE_DIR/xreal-connected"
SYNC_LOCK="${XDG_RUNTIME_DIR:-/tmp}/omarchy-xreal-laptop.sync.lock"
DAEMON_LOCK="${XDG_RUNTIME_DIR:-/tmp}/omarchy-xreal-laptop.lock"

xreal_present() {
  local edid status saw_drm=0

  for edid in /sys/class/drm/card*-*/edid; do
    [[ -e $edid ]] || continue
    saw_drm=1
    status="${edid%/edid}/status"
    [[ -f $status && $(<"$status") == connected ]] || continue
    if strings "$edid" 2>/dev/null | grep -qiE 'xreal|nreal'; then
      return 0
    fi
  done

  # Sysfs is authoritative when it exists. Only ask Hyprland if it doesn't.
  (( saw_drm )) && return 1

  hyprctl monitors all -j 2>/dev/null | jq -e '
    .[] | select((.description // "") | test("xreal|nreal"; "i"))
  ' >/dev/null 2>&1
}

other_external_active() {
  hyprctl monitors all -j 2>/dev/null | jq -e '
    .[]
    | select(.disabled == false)
    | select(.name | test("^(eDP|LVDS|DSI)-|^FALLBACK$|^HEADLESS") | not)
    | select((.description // "") | test("xreal|nreal"; "i") | not)
  ' >/dev/null 2>&1
}

# Omarchy scale selector preset: 1.6 on the glasses.
apply_xreal_scale() {
  local info name width height refresh

  info=$(hyprctl monitors all -j 2>/dev/null | jq -e -c '
    .[] | select(.disabled == false) | select((.description // "") | test("xreal|nreal"; "i"))
  ' | head -1) || return 0

  name=$(jq -r '.name' <<<"$info")
  [[ $name =~ ^[A-Za-z0-9._-]+$ ]] || return 0

  awk -v scale="$(jq -r '.scale' <<<"$info")" 'BEGIN { exit !(scale + 0 == 1.6) }' && return 0

  width=$(jq -r '.width' <<<"$info")
  height=$(jq -r '.height' <<<"$info")
  refresh=$(jq -r '.refreshRate' <<<"$info")
  hyprctl eval "hl.monitor({ output = \"$name\", mode = \"${width}x${height}@${refresh}\", position = \"auto\", scale = 1.6 })" >/dev/null
}

sync_laptop() {
  mkdir -p "$STATE_DIR"

  (
    flock 8

    if xreal_present; then
      if [[ ! -f $CONNECTED_FLAG ]]; then
        touch "$CONNECTED_FLAG"
        omarchy-hyprland-monitor-internal off
        apply_xreal_scale
      fi
    else
      if [[ -f $CONNECTED_FLAG ]]; then
        rm -f "$CONNECTED_FLAG"
        omarchy-hyprland-monitor-internal on
      elif omarchy-hyprland-toggle-enabled internal-monitor-disable && ! other_external_active; then
        # Leftover disable after an unplug the compositor did not recover from.
        omarchy-hyprland-monitor-internal on
      fi
    fi
  ) 8>"$SYNC_LOCK"
}

if [[ ${1:-} == --once ]]; then
  sync_laptop
  exit 0
fi

exec 9>"$DAEMON_LOCK"
flock -n 9 || exit 0

sync_laptop

while true; do
  sleep 1
  sync_laptop
done
