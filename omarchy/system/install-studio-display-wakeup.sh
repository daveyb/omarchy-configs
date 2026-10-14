#!/bin/bash
# Install clamshell/AC lid policy and Studio Display USB wakeup rules.
set -euo pipefail

if (( EUID != 0 )); then
  echo "This installer must run as root." >&2
  exit 1
fi

src_dir="${1:-/home/david/.config/omarchy/system}"
install -d /etc/systemd/logind.conf.d /etc/systemd/sleep.conf.d /etc/udev/rules.d
install -m 644 "$src_dir/30-clamshell-ac.conf" /etc/systemd/logind.conf.d/30-clamshell-ac.conf
install -m 644 "$src_dir/10-hibernate-delay.conf" /etc/systemd/sleep.conf.d/10-hibernate-delay.conf
install -m 644 "$src_dir/98-studio-display-wakeup.rules" /etc/udev/rules.d/98-studio-display-wakeup.rules

udevadm control --reload
udevadm trigger --subsystem-match=pci --action=add
udevadm trigger --subsystem-match=usb --action=add
udevadm trigger --subsystem-match=thunderbolt --action=add

apply_sysfs() {
  local path="$1" value="$2"
  [[ -e $path ]] || return 0
  printf '%s\n' "$value" >"$path" 2>/dev/null || true
}

# Live-apply so this session does not wait for the next plug-in.
for pci in /sys/bus/pci/devices/*; do
  vendor=$(<"$pci/vendor") device=$(<"$pci/device")
  case "$vendor:$device" in
    0x8086:0x15f0)
      apply_sysfs "$pci/d3cold_allowed" 0
      apply_sysfs "$pci/power/control" on
      apply_sysfs "$pci/power/wakeup" enabled
      ;;
    0x8086:0x15ef|0x8086:0x9a23|0x8086:0x9a25|0x8086:0x9a13|0x8086:0x9a1b)
      apply_sysfs "$pci/d3cold_allowed" 0
      apply_sysfs "$pci/power/wakeup" enabled
      ;;
  esac
done

for tb in /sys/bus/thunderbolt/devices/*; do
  [[ -e $tb/device_name ]] || continue
  [[ $(<"$tb/device_name") == "Studio Display" ]] || continue
  apply_sysfs "$tb/power/control" on
done

for usb in /sys/bus/usb/devices/*; do
  [[ -e $usb/idVendor && -e $usb/power/wakeup ]] || continue
  vendor=$(<"$usb/idVendor")
  product=$(<"$usb/idProduct" 2>/dev/null || true)
  # Match 98-studio-display-wakeup.rules. Leave Linux root hubs (1d6b)
  # disabled so a USB-C jostle cannot wake S4 into LUKS.
  case "$vendor" in
    05ac|05e3|046d) apply_sysfs "$usb/power/wakeup" enabled ;;
    04f2) [[ $product == 1830 ]] && apply_sysfs "$usb/power/wakeup" enabled ;;
  esac
done

# HandleLid* is const. Do not restart systemd-logind here: on this XPS
# that breaks the Hyprland Wayland socket and drops the session to a
# greeter/LUKS-looking screen. daemon-reload is enough for sleep.conf.d.
# Lid-close already hibernates from the session bind; logind picks up
# HandleLid* on its next start (reboot).
systemctl daemon-reload

echo "Installed lid policy files (no logind restart). Reboot once for HandleLid* to go live in logind."
