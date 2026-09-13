#!/bin/bash
# Restrict ACPI/USB/Thunderbolt wake so a closed lid in a bag cannot be
# jostled into a LUKS screen. Lid switch and power button still wake.
# When a Studio Display (or other external panel) is actually present,
# Thunderbolt/USB wake is turned back on for the keyboard.

log() { logger -t omarchy-lid-wake-policy -- "$*"; }

acpi_set() {
  local dev=$1 want=$2 line
  [[ -r /proc/acpi/wakeup ]] || return 0
  line=$(awk -v d="$dev" '$1 == d { print; exit }' /proc/acpi/wakeup)
  [[ -n $line ]] || return 0
  if [[ $line == *'*enabled'* ]]; then
    [[ $want == enabled ]] && return 0
  else
    [[ $want == disabled ]] && return 0
  fi
  printf '%s\n' "$dev" >/proc/acpi/wakeup
}

studio_display_present() {
  local f
  for f in /sys/bus/thunderbolt/devices/*/device_name; do
    [[ -e $f ]] || continue
    [[ $(<"$f") == "Studio Display" ]] && return 0
  done
  return 1
}

usb_wakeup() {
  local f val=$1
  for f in /sys/bus/usb/devices/usb*/power/wakeup; do
    [[ -e $f ]] || continue
    printf '%s\n' "$val" >"$f" 2>/dev/null || true
  done
}

# Devices that woke this XPS from S4 via USB-C/TB in a bag. Never touch
# LID0 or PBTN — those are how an intentional open/power-on resumes.
BAG_WAKE=(XHCI TXHC TDM0 TRP0 TRP1 PEG0 RP01 RP12)

if studio_display_present || omarchy-hw-external-monitors 2>/dev/null; then
  log "external display present; enabling TB/USB wake"
  for d in TXHC TDM0 TRP0 TRP1 XHCI; do
    acpi_set "$d" enabled
  done
  usb_wakeup enabled
else
  log "no external display; disabling TB/USB S4 wake"
  for d in "${BAG_WAKE[@]}"; do
    acpi_set "$d" disabled
  done
  usb_wakeup disabled
fi
