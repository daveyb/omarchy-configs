#!/bin/bash
# Lid close: lock, reconcile clamshell displays, then hibernate when this is a
# real laptop lid close (no external monitor) — including on AC.
#
# logind hibernates on lid close (battery and AC). This script is the
# session backup: hibernate whenever the lid is shut with no external
# display, so a charger in a hotel cannot leave the machine awake.
#
# This XPS 13 only has s2idle (not S3). s2idle still draws ~2W and runs warm,
# which is a bag-of-death with the lid shut and no ventilation. Hibernate
# writes RAM to disk and powers off. Do not use suspend-then-hibernate here:
# that s2idle's for HibernateDelaySec, then wakes at full power in the bag
# to write the image.
#
# --sleep-only  skip lock/clamshell; used by lid-sleep-guard after debounce.

log() { logger -t omarchy-lid-close -- "$*"; }

already_leaving() {
  if systemctl is-system-running 2>/dev/null | grep -qx stopping; then
    return 0
  fi
  # Do not treat an in-flight s2idle as a reason to skip: that is the
  # bag-of-death path we are replacing. Only a real poweroff/reboot must win.
  if systemctl list-jobs --no-legend 2>/dev/null | grep -Eq \
    'poweroff\.target|reboot\.target|halt\.target|hibernate\.target'; then
    return 0
  fi
  return 1
}

hibernate_if_undocked_lid() {
  already_leaving && return 0

  if ! omarchy-hw-laptop-closed; then
    return 0
  fi
  if omarchy-hw-external-monitors; then
    log "lid closed with an external display; staying awake (clamshell)"
    return 0
  fi

  # Userspace blank. Root sysfs blanking is the systemd-sleep hook, because
  # intel_backlight is not writable as the session user.
  hyprctl dispatch 'hl.dsp.dpms({ action = "off" })' >/dev/null 2>&1 || true

  local lock="${XDG_RUNTIME_DIR:-/tmp}/omarchy-lid-hibernate.lock"
  (
    flock -n 8 || exit 0
    already_leaving && exit 0
    log "lid closed, no external display; hibernating"
    systemctl hibernate --no-wall
  ) 8>"$lock"
}

if [[ ${1:-} == --sleep-only ]]; then
  hibernate_if_undocked_lid
  exit 0
fi

omarchy-system-lid-close || true
hibernate_if_undocked_lid
