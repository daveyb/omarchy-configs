#!/bin/sh
# Blank the laptop panel while the lid is shut. Plymouth/LUKS, i915, and
# systemd-backlight all restore brightness on their own; this wins while
# the lid is closed and puts the previous level back when it opens.
#
#   --force  blank even if the lid reads open (pre-sleep / lid-close path)
#   --watch  initramfs: blank while closed; if the lid stays shut for 10s
#            at the LUKS prompt, power off (hibernation image is kept).
#            A bag jostle that wakes S4 must not sit at Plymouth drawing
#            heat with the panel on.

STATE=/run/omarchy-lid-panel-off
force=0
watch=0
for arg in "$@"; do
  case $arg in
    --force) force=1 ;;
    --watch) watch=1 ;;
  esac
done

lid_closed() {
  for s in /proc/acpi/button/lid/*/state; do
    [ -r "$s" ] || continue
    grep -q closed "$s" && return 0
  done
  return 1
}

save_if_on() {
  mkdir -p "$STATE"
  for b in /sys/class/backlight/*/brightness; do
    [ -e "$b" ] || continue
    dir=$(dirname "$b")
    name=$(basename "$dir")
    cur=$(cat "$b" 2>/dev/null) || continue
    [ -n "$cur" ] || continue
    if [ "$cur" -gt 0 ] 2>/dev/null; then
      printf '%s\n' "$cur" >"$STATE/$name.brightness"
      if [ -e "$dir/bl_power" ]; then
        cat "$dir/bl_power" >"$STATE/$name.bl_power" 2>/dev/null || true
      fi
    fi
  done
}

blank() {
  save_if_on
  for b in /sys/class/backlight/*/brightness; do
    [ -e "$b" ] || continue
    echo 0 >"$b" 2>/dev/null || true
  done
  for b in /sys/class/backlight/*/bl_power; do
    [ -e "$b" ] || continue
    echo 4 >"$b" 2>/dev/null || true
  done
}

restore() {
  [ -d "$STATE" ] || return 0
  for f in "$STATE"/*.brightness; do
    [ -e "$f" ] || continue
    name=$(basename "$f" .brightness)
    dir=/sys/class/backlight/$name
    [ -e "$dir/brightness" ] || continue
    if [ -e "$STATE/$name.bl_power" ]; then
      cat "$STATE/$name.bl_power" >"$dir/bl_power" 2>/dev/null || true
    else
      echo 0 >"$dir/bl_power" 2>/dev/null || true
    fi
    cat "$f" >"$dir/brightness" 2>/dev/null || true
  done
}

poweroff_now() {
  printf 'omarchy-lid-panel-off: lid closed at LUKS/initramfs; powering off\n' >/dev/kmsg 2>/dev/null || true
  echo 1 >/proc/sys/kernel/sysrq 2>/dev/null || true
  echo o >/proc/sysrq-trigger 2>/dev/null || true
  poweroff -f 2>/dev/null || true
  halt -f 2>/dev/null || true
}

if [ "$watch" -eq 1 ]; then
  n=0
  while :; do
    if lid_closed; then
      blank
      n=$((n + 1))
      if [ "$n" -ge 10 ]; then
        poweroff_now
        n=0
      fi
    else
      n=0
      restore
    fi
    sleep 1
  done
fi

if [ "$force" -eq 1 ] || lid_closed; then
  blank
else
  restore
fi
