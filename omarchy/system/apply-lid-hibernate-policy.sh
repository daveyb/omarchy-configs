#!/bin/bash
# Run in a visible terminal so sudo can ask for a password.
set -euo pipefail

echo
echo "Installs the lid/chipset stack:"
echo "  - hibernate on lid close (battery and AC)"
echo "  - initramfs: if lid stays closed at LUKS, power off (bag wake)"
echo "  - disable USB/Thunderbolt S4 wake unless an external display is present"
echo "  - does NOT restart logind (that crashed Hyprland last time)"
echo
sudo /home/david/.config/omarchy/system/install-lid-chipset.sh /home/david/.config/omarchy/system
echo
echo "Installed:"
grep -E '^HandleLid|^LidSwitch|^HibernateDelay' \
  /etc/systemd/logind.conf.d/30-clamshell-ac.conf \
  /etc/systemd/sleep.conf.d/10-hibernate-delay.conf || true
echo
echo "ACPI wakeup (XHCI/TB should be disabled unless a display is plugged in):"
awk '$1 ~ /^(XHCI|TXHC|TDM0|TRP0|TRP1|LID0|PBTN)$/ { print }' /proc/acpi/wakeup
echo
