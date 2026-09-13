#!/bin/bash
# Closed lid + no external display must hibernate.
#
# Also holds a logind lid-switch inhibitor while an external display is
# connected, so Studio Display clamshell stays awake without treating "on
# AC" as docked. Debounce the release so a Thunderbolt blip does not drop
# the inhibitor and hibernate a clamshell session.

INTERVAL=5
NEEDED=3 # 15s with no external display
LID_CLOSE="${HOME}/.config/hypr/scripts/lid-close.sh"
DAEMON_LOCK="${XDG_RUNTIME_DIR:-/tmp}/omarchy-lid-sleep-guard.lock"

exec 9>"$DAEMON_LOCK"
flock -n 9 || exit 0

hits=0
inhibit_pid=""

sleep_in_flight() {
  systemctl list-jobs --no-legend 2>/dev/null | grep -Eq \
    'hibernate\.target|suspend\.target|hybrid-sleep\.target|suspend-then-hibernate\.target' \
    && return 0
  systemctl is-active --quiet systemd-hibernate.service 2>/dev/null && return 0
  systemctl is-active --quiet systemd-suspend.service 2>/dev/null && return 0
  systemctl is-active --quiet systemd-suspend-then-hibernate.service 2>/dev/null && return 0
  return 1
}

hold_lid_inhibit() {
  sleep_in_flight && return 0
  if [[ -n $inhibit_pid ]] && kill -0 "$inhibit_pid" 2>/dev/null; then
    return 0
  fi
  systemd-inhibit --what=handle-lid-switch --who=omarchy-clamshell \
    --why="external display connected" --mode=block sleep infinity &
  inhibit_pid=$!
  logger -t omarchy-lid-sleep-guard -- "holding lid-switch inhibit (pid $inhibit_pid)"
}

drop_lid_inhibit() {
  if [[ -n $inhibit_pid ]]; then
    kill "$inhibit_pid" 2>/dev/null || true
    wait "$inhibit_pid" 2>/dev/null || true
    logger -t omarchy-lid-sleep-guard -- "released lid-switch inhibit"
    inhibit_pid=""
  fi
}

trap 'drop_lid_inhibit; exit 0' EXIT INT TERM

logger -t omarchy-lid-sleep-guard -- "watching lid and displays"

while true; do
  sleep "$INTERVAL"

  if systemctl is-system-running 2>/dev/null | grep -qx stopping; then
    hits=0
    continue
  fi
  if sleep_in_flight; then
    hits=0
    continue
  fi

  if omarchy-hw-external-monitors; then
    hits=0
    hold_lid_inhibit
    continue
  fi

  hits=$((hits + 1))
  if ((hits < NEEDED)); then
    continue
  fi

  drop_lid_inhibit
  hits=0

  if omarchy-hw-laptop-closed; then
    logger -t omarchy-lid-sleep-guard -- "lid closed with no external display for $((INTERVAL * NEEDED))s; hibernating"
    "$LID_CLOSE" --sleep-only || true
    sleep 30
  fi
done
