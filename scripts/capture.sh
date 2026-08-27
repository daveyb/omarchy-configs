#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOME_HYPR="${HOME}/.config/hypr"
HOME_OMARCHY="${HOME}/.config/omarchy"

copy_file() {
	local src="$1"
	local dest="$2"
	if [[ ! -f $src ]]; then
		echo "missing $src" >&2
		exit 1
	fi
	mkdir -p "$(dirname "$dest")"
	cp -a "$src" "$dest"
}

copy_file "$HOME_HYPR/input.lua" "$ROOT/hypr/input.lua"
copy_file "$HOME_HYPR/monitors.lua" "$ROOT/hypr/monitors.lua"
copy_file "$HOME_HYPR/autostart.lua" "$ROOT/hypr/autostart.lua"
copy_file "$HOME_HYPR/scripts/xreal-laptop.sh" "$ROOT/hypr/scripts/xreal-laptop.sh"
copy_file "$HOME_OMARCHY/shell.json" "$ROOT/omarchy/shell.json"
copy_file "$HOME_OMARCHY/defaults/agent" "$ROOT/omarchy/defaults/agent"
copy_file "${HOME}/.XCompose" "$ROOT/xcompose/XCompose"

mkdir -p "$ROOT/git"
{
	printf '[user]\n'
	printf '\tname = %s\n' "$(git config --global --get user.name)"
	printf '\temail = %s\n' "$(git config --global --get user.email)"
} >"$ROOT/git/config"

mkdir -p "$ROOT/cidata"
git config --global --get user.name >"$ROOT/cidata/user_full_name.txt"
git config --global --get user.email >"$ROOT/cidata/user_email_address.txt"
# This host uses LUKS. The passphrase stays off this tree.
printf 'true\n' >"$ROOT/cidata/user_encrypt_installation.txt"

mkdir -p "$ROOT/packages"
comm -23 \
	<(pacman -Qqe | sort) \
	<(
		{
			cat /usr/share/omarchy/install/omarchy-base.packages \
				/usr/share/omarchy/install/omarchy-other.packages
			printf '%s\n' omarchy omarchy-keyring omarchy-settings sudo mkinitcpio \
				intel-ucode usbutils efibootmgr base linux linux-firmware
		} | grep -v '^#' | grep -v '^$' | sort -u
	) >"$ROOT/packages/extras.txt"

mkdir -p "$ROOT/omarchy"
if [[ -d $HOME_OMARCHY/plugins ]]; then
	find "$HOME_OMARCHY/plugins" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
		| sort >"$ROOT/omarchy/plugins.txt"
else
	: >"$ROOT/omarchy/plugins.txt"
fi

echo "captured into $ROOT"
