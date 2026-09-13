#!/bin/bash
# Install closed-lid panel blanking for sleep, hibernate, and LUKS/Plymouth.
set -euo pipefail

if (( EUID != 0 )); then
  echo "This installer must run as root." >&2
  exit 1
fi

src_dir="${1:-/home/david/.config/omarchy/system}"

install -d /usr/local/libexec /usr/lib/systemd/system-sleep /etc/udev/rules.d
install -d /etc/systemd/system/systemd-hibernate.service.d
install -d /etc/systemd/system/systemd-suspend-then-hibernate.service.d
install -d /etc/initcpio/install

install -m 755 "$src_dir/lid-panel-off.sh" /usr/local/libexec/omarchy-lid-panel-off
install -m 755 "$src_dir/lid-panel-off.sleep" /usr/lib/systemd/system-sleep/lid-panel-off
install -m 644 "$src_dir/99-lid-panel-off.rules" /etc/udev/rules.d/99-lid-panel-off.rules
install -m 644 "$src_dir/lid-panel-off.service" /etc/systemd/system/lid-panel-off.service
install -m 644 "$src_dir/20-freeze-sessions.conf" \
  /etc/systemd/system/systemd-hibernate.service.d/20-freeze-sessions.conf
install -m 644 "$src_dir/20-freeze-sessions.conf" \
  /etc/systemd/system/systemd-suspend-then-hibernate.service.d/20-freeze-sessions.conf
install -d /etc/initcpio/hooks
install -m 644 "$src_dir/initcpio-install-lid-panel-off" /etc/initcpio/install/lid-panel-off
install -m 644 "$src_dir/initcpio-hook-lid-panel-off" /etc/initcpio/hooks/lid-panel-off
install -d /etc/mkinitcpio.conf.d
install -m 644 "$src_dir/zz-lid-panel-off.conf" /etc/mkinitcpio.conf.d/zz-lid-panel-off.conf

# Omarchy's drop-in owns HOOKS. Do not edit omarchy_hooks.conf; a later
# zz- drop-in appends lid-panel-off. Undo a comment rewrite from an
# earlier installer if it is still present.
if [[ -f /etc/mkinitcpio.conf ]]; then
  python3 - <<'PY'
from pathlib import Path
p = Path("/etc/mkinitcpio.conf")
text = p.read_text()
fixed = text.replace("kms lid-panel-off ", "kms ")
if fixed != text:
    p.write_text(fixed)
PY
fi

systemctl daemon-reload
systemctl enable lid-panel-off.service
udevadm control --reload
udevadm trigger --subsystem-match=input --action=change || true

if command -v limine-mkinitcpio >/dev/null; then
  limine-mkinitcpio
elif command -v mkinitcpio >/dev/null; then
  /usr/bin/mkinitcpio -P
fi

echo "Installed closed-lid panel blanking for sleep, hibernate, and LUKS/Plymouth."
