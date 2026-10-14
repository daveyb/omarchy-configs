#!/bin/bash
# Install shutdown-safety units: do not reboot-force when the TPM PCR
# barrier fails during poweroff, and blank the panel in systemd-shutdown.
set -euo pipefail

if (( EUID != 0 )); then
  echo "This installer must run as root." >&2
  exit 1
fi

src_dir="${1:-/home/david/.config/omarchy/system}"

install -d /etc/systemd/system/systemd-pcrphase.service.d
install -d /etc/systemd/system/systemd-pcrphase-sysinit.service.d
install -d /etc/systemd/system-shutdown

install -m 644 "$src_dir/systemd-pcrphase-no-force-reboot-on-stop.conf" \
  /etc/systemd/system/systemd-pcrphase.service.d/no-force-reboot-on-stop.conf
install -m 644 "$src_dir/systemd-pcrphase-no-force-reboot-on-stop.conf" \
  /etc/systemd/system/systemd-pcrphase-sysinit.service.d/no-force-reboot-on-stop.conf
install -m 755 "$src_dir/panel-off.shutdown" \
  /etc/systemd/system-shutdown/panel-off

systemctl daemon-reload

echo "Installed pcrphase stop-failure drop-ins and shutdown panel-off."
