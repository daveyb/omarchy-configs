#!/bin/bash

# While the Apple Studio Display is actually showing a picture, it is the
# only screen, at its highest mode and 1:1 scale. The laptop panel comes
# back when the display's video link drops. DRM EDID decides whether the
# panel is still attached so a stale Hyprland head cannot keep the laptop off.

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy"
CONNECTED_FLAG="$STATE_DIR/studio-display-only"
MISS_FILE="${XDG_RUNTIME_DIR:-/tmp}/omarchy-studio-display-only.misses"
SYNC_LOCK="${XDG_RUNTIME_DIR:-/tmp}/omarchy-studio-display-only.sync.lock"
DAEMON_LOCK="${XDG_RUNTIME_DIR:-/tmp}/omarchy-studio-display-only.lock"

studio_drm() {
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

xreal_drm() {
  local edid status

  for edid in /sys/class/drm/card*-*/edid; do
    [[ -e $edid ]] || continue
    status="${edid%/edid}/status"
    [[ -f $status && $(<"$status") == connected ]] || continue
    if strings "$edid" 2>/dev/null | command grep -qiE 'xreal|nreal'; then
      return 0
    fi
  done
  return 1
}

scales_match() {
  awk -v left="$1" -v right="$2" 'BEGIN {
    diff = left - right
    if (diff < 0) diff = -diff
    exit(diff < 0.001 ? 0 : 1)
  }'
}

# JSON array of Studio Display heads, highest mode first.
studio_heads() {
  hyprctl monitors all -j 2>/dev/null | jq -c '
    def mode_rank:
      if type == "string" and test("^[0-9]+x[0-9]+@[0-9.]+") then
        capture("^(?<w>[0-9]+)x(?<h>[0-9]+)@(?<r>[0-9.]+)") as $m
        | {pixels: (($m.w | tonumber) * ($m.h | tonumber)), refresh: ($m.r | tonumber), mode: "\($m.w)x\($m.h)@\($m.r)"}
      else
        empty
      end;
    [
      .[]
      | select((.description // "") | test("studiodisplay|studio display"; "i"))
      | . as $mon
      | (($mon.availableModes // []) | map(mode_rank) | max_by(.pixels * 1000 + .refresh)) as $best
      | $mon + {
          best_mode: (($best // {}).mode // ""),
          best_pixels: (($best // {}).pixels // 0)
        }
    ]
    | sort_by([.best_pixels, (.width * .height)])
    | reverse
  '
}

apply_head() {
  local info="$1" name mode

  name=$(jq -r '.name' <<<"$info")
  [[ $name =~ ^[A-Za-z0-9._-]+$ ]] || return 0
  mode=$(jq -r '.best_mode // ""' <<<"$info")
  [[ -n $mode ]] || mode="highres"

  local pixels best
  pixels=$(jq -r '.width * .height' <<<"$info")
  best=$(jq -r '.best_pixels' <<<"$info")
  if jq -e '.disabled == false and .width > 0 and .height > 0 and .x == 0 and .y == 0' <<<"$info" >/dev/null \
    && scales_match "$(jq -r '.scale' <<<"$info")" 1 \
    && { [[ $best == 0 ]] || [[ $pixels == "$best" ]]; }; then
    return 0
  fi

  hyprctl eval "hl.monitor({ output = \"$name\", mode = \"$mode\", position = \"0x0\", scale = 1 })" >/dev/null
}

disable_head() {
  local name="$1"
  [[ $name =~ ^[A-Za-z0-9._-]+$ ]] || return 0
  hyprctl eval "hl.monitor({ output = \"$name\", disabled = true })" >/dev/null
}

enable_laptop() {
  xreal_drm && return 0
  omarchy-hyprland-monitor-internal on >/dev/null 2>&1 || true
}

sync_display() {
  local heads primary extra name

  mkdir -p "$STATE_DIR"

  (
    flock 8

    if ! studio_drm; then
      rm -f "$MISS_FILE"
      if [[ -f $CONNECTED_FLAG ]]; then
        rm -f "$CONNECTED_FLAG"
        enable_laptop
      fi
      exit 0
    fi

    heads=$(studio_heads)
    primary=$(jq -c '.[0] // empty | select(.width > 0 and .height > 0 and .disabled == false)' <<<"$heads")

    if [[ -z $primary ]]; then
      if [[ -f $CONNECTED_FLAG ]]; then
        local misses=0
        [[ -f $MISS_FILE ]] && misses=$(<"$MISS_FILE")
        misses=$((misses + 1))
        printf '%s\n' "$misses" >"$MISS_FILE"
        if ((misses >= 5)); then
          rm -f "$MISS_FILE" "$CONNECTED_FLAG"
          enable_laptop
        fi
      fi
      exit 0
    fi

    rm -f "$MISS_FILE"
    apply_head "$primary"

    while IFS= read -r extra; do
      [[ -n $extra ]] || continue
      jq -e '.disabled == false' <<<"$extra" >/dev/null || continue
      name=$(jq -r '.name' <<<"$extra")
      disable_head "$name"
    done < <(jq -c '.[1:][]?' <<<"$heads")

    if omarchy-hyprland-monitor-external-active; then
      touch "$CONNECTED_FLAG"
      omarchy-hyprland-monitor-internal off >/dev/null 2>&1 || true
    fi
  ) 8>"$SYNC_LOCK"
}

if [[ ${1:-} == --once ]]; then
  sync_display
  exit 0
fi

exec 9>"$DAEMON_LOCK"
flock -n 9 || exit 0

sync_display

while true; do
  sleep 1
  sync_display
done
