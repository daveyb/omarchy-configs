#!/bin/bash

# When the Apple Studio Display unplugs, Hyprland keeps the 5K scale on the
# remaining head (1080p 3.2x becomes 3.33x). Force the laptop default back.
#
# Omarchy's scale selector also rewrites omarchy_monitor_scale in monitors.lua
# to the focused monitor's scale, so a SUPER+/ on the Studio Display poisons
# the laptop default until we write 1.25 back.

DEFAULT_SCALE=1.25
DEFAULT_GDK_SCALE=1
MONITOR_LUA="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/monitors.lua"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy"
SYNC_LOCK="${XDG_RUNTIME_DIR:-/tmp}/omarchy-studio-display-scale.sync.lock"
RETRY_LOCK="${XDG_RUNTIME_DIR:-/tmp}/omarchy-studio-display-scale.retry.lock"
DAEMON_LOCK="${XDG_RUNTIME_DIR:-/tmp}/omarchy-studio-display-scale.lock"

studio_present() {
  local edid status saw_drm=0

  for edid in /sys/class/drm/card*-*/edid; do
    [[ -e $edid ]] || continue
    saw_drm=1
    status="${edid%/edid}/status"
    [[ -f $status && $(<"$status") == connected ]] || continue
    if strings "$edid" 2>/dev/null | command grep -qiE 'studiodisplay|studio display'; then
      return 0
    fi
  done

  (( saw_drm )) && return 1

  hyprctl monitors all -j 2>/dev/null | jq -e '
    .[] | select((.description // "") | test("studiodisplay|studio display"; "i"))
  ' >/dev/null 2>&1
}

xreal_desc() {
  command grep -qiE 'xreal|nreal' <<<"$1"
}

studio_desc() {
  command grep -qiE 'studiodisplay|studio display' <<<"$1"
}

scales_match() {
  awk -v left="$1" -v right="$2" 'BEGIN {
    diff = left - right
    if (diff < 0) diff = -diff
    exit(diff < 0.001 ? 0 : 1)
  }'
}

apply_monitor_scale() {
  local name="$1"
  local scale="$2"
  local position="$3"
  local info width height refresh

  [[ $name =~ ^[A-Za-z0-9._-]+$ ]] || return 0

  info=$(hyprctl monitors all -j 2>/dev/null | jq -e -c --arg name "$name" '
    .[] | select(.name == $name) | select(.disabled == false)
  ') || return 0

  awk -v scale="$(jq -r '.scale' <<<"$info")" -v want="$scale" 'BEGIN {
    diff = scale - want
    if (diff < 0) diff = -diff
    exit(diff < 0.001 ? 0 : 1)
  }' && return 0

  width=$(jq -r '.width' <<<"$info")
  height=$(jq -r '.height' <<<"$info")
  refresh=$(jq -r '.refreshRate' <<<"$info")
  hyprctl eval "hl.monitor({ output = \"$name\", mode = \"${width}x${height}@${refresh}\", position = \"$position\", scale = $scale })" >/dev/null
}

restore_lua_defaults() {
  local current_scale current_gdk

  [[ -f $MONITOR_LUA ]] || return 0
  command grep -q '^local omarchy_monitor_scale = ' "$MONITOR_LUA" || return 0

  current_scale=$(sed -nE 's/^local omarchy_monitor_scale = ([0-9.]+).*/\1/p' "$MONITOR_LUA" | head -1)
  current_gdk=$(sed -nE 's/^local omarchy_gdk_scale = ([0-9.]+).*/\1/p' "$MONITOR_LUA" | head -1)

  if scales_match "${current_scale:-}" "$DEFAULT_SCALE" &&
    [[ ${current_gdk:-} == "$DEFAULT_GDK_SCALE" ]]; then
    return 0
  fi

  sed -i -E \
    -e "s|^local omarchy_monitor_scale = .*|local omarchy_monitor_scale = ${DEFAULT_SCALE}|" \
    -e "s|^local omarchy_gdk_scale = .*|local omarchy_gdk_scale = ${DEFAULT_GDK_SCALE}|" \
    "$MONITOR_LUA"
}

sync_scale() {
  local info name desc position

  mkdir -p "$STATE_DIR"

  (
    flock 8

    studio_present && exit 0

    restore_lua_defaults

    while IFS= read -r info; do
      [[ -n $info ]] || continue
      name=$(jq -r '.name' <<<"$info")
      desc=$(jq -r '.description // ""' <<<"$info")
      xreal_desc "$desc" && continue
      studio_desc "$desc" && continue
      [[ $name =~ ^(FALLBACK|HEADLESS) ]] && continue

      position=auto
      [[ $name == eDP-1 ]] && position=auto-down
      apply_monitor_scale "$name" "$DEFAULT_SCALE" "$position"
    done < <(hyprctl monitors all -j 2>/dev/null | jq -c '.[] | select(.disabled == false)' 2>/dev/null)
  ) 8>"$SYNC_LOCK"
}

sync_with_retries() {
  sync_scale

  # Clamshell re-enables the laptop a few seconds after unplug. Catch that.
  (
    flock -n 9 || exit 0
    for delay in 1 3 7; do
      sleep "$delay"
      sync_scale
    done
  ) 9>"$RETRY_LOCK" &
}

if [[ ${1:-} == --once ]]; then
  sync_with_retries
  exit 0
fi

exec 9>"$DAEMON_LOCK"
flock -n 9 || exit 0

sync_scale

while true; do
  sleep 1
  sync_scale
done
