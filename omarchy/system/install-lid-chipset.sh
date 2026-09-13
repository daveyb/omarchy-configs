#!/bin/bash
# Chipset/lid stack: logind hibernate policy, initramfs LUKS bag-guard,
# and USB/Thunderbolt S4 wake restricted unless an external display is present.
# Does not restart systemd-logind (that tears down Hyprland on this machine).
set -euo pipefail

if (( EUID != 0 )); then
  echo "This installer must run as root." >&2
  exit 1
fi

src_dir="${1:-/home/david/.config/omarchy/system}"

install -d /etc/systemd/logind.conf.d /etc/systemd/sleep.conf.d
install -d /usr/local/libexec /usr/lib/systemd/system-sleep /etc/udev/rules.d
install -d /etc/systemd/system/systemd-hibernate.service.d
install -d /etc/systemd/system/systemd-suspend-then-hibernate.service.d
install -d /etc/initcpio/install /etc/initcpio/hooks /etc/mkinitcpio.conf.d

install -m 644 "$src_dir/30-clamshell-ac.conf" /etc/systemd/logind.conf.d/30-clamshell-ac.conf
install -m 644 "$src_dir/10-hibernate-delay.conf" /etc/systemd/sleep.conf.d/10-hibernate-delay.conf
install -m 644 "$src_dir/98-studio-display-wakeup.rules" /etc/udev/rules.d/98-studio-display-wakeup.rules
install -m 644 "$src_dir/99-lid-wake-policy.rules" /etc/udev/rules.d/99-lid-wake-policy.rules
install -m 644 "$src_dir/99-lid-panel-off.rules" /etc/udev/rules.d/99-lid-panel-off.rules

install -m 755 "$src_dir/lid-panel-off.sh" /usr/local/libexec/omarchy-lid-panel-off
install -m 755 "$src_dir/lid-panel-off.sleep" /usr/lib/systemd/system-sleep/lid-panel-off
install -m 755 "$src_dir/lid-wake-policy.sh" /usr/local/libexec/omarchy-lid-wake-policy
install -m 644 "$src_dir/lid-panel-off.service" /etc/systemd/system/lid-panel-off.service
install -m 644 "$src_dir/lid-wake-policy.service" /etc/systemd/system/lid-wake-policy.service
install -m 644 "$src_dir/20-freeze-sessions.conf" \
  /etc/systemd/system/systemd-hibernate.service.d/20-freeze-sessions.conf
install -m 644 "$src_dir/20-freeze-sessions.conf" \
  /etc/systemd/system/systemd-suspend-then-hibernate.service.d/20-freeze-sessions.conf

install -m 644 "$src_dir/initcpio-install-lid-panel-off" /etc/initcpio/install/lid-panel-off
install -m 644 "$src_dir/initcpio-hook-lid-panel-off" /etc/initcpio/hooks/lid-panel-off
install -m 644 "$src_dir/zz-lid-panel-off.conf" /etc/mkinitcpio.conf.d/zz-lid-panel-off.conf

systemctl daemon-reload
systemctl enable lid-panel-off.service lid-wake-policy.service
udevadm control --reload
udevadm trigger --subsystem-match=input --action=change || true
/usr/local/libexec/omarchy-lid-wake-policy || true

# HandleLid* is const. Restarting logind on this XPS kills Hyprland
# (Wayland socket broken pipe). The drop-in is on disk; it applies at
# the next logind start (reboot / session). Live lid-close already
# hibernates via the Hyprland bind.
systemctl daemon-reload

if command -v limine-mkinitcpio >/dev/null; then
  limine-mkinitcpio
elif command -v mkinitcpio >/dev/null; then
  /usr/bin/mkinitcpio -P
fi

echo "Installed lid chipset stack (hibernate policy, LUKS bag-guard, restricted S4 wake)."
echo "logind was NOT restarted (that crashes Hyprland here). Reboot once so HandleLidSwitch=hibernate is live in logind."
