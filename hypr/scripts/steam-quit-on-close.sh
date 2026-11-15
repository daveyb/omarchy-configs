#!/bin/bash

# Steam destroys its window on close and keeps the process for the tray icon.
# Called after the main Steam window closes. Quit the client unless a Steam
# window is still on screen or a game is running (the client has to stay up
# for that). A short wait covers Steam swapping the window during startup.

set -u

closing_address="${1:-}"
lock="${XDG_RUNTIME_DIR:-/tmp}/steam-quit-on-close.lock"

exec 9>"$lock"
flock -n 9 || exit 0

sleep 0.6

decision="$(
  CLOSING_ADDRESS="$closing_address" python3 - <<'PY'
import json, os, subprocess, sys

closing = os.environ.get("CLOSING_ADDRESS", "").lower().removeprefix("0x")

def clients():
    try:
        raw = subprocess.check_output(["hyprctl", "clients", "-j"], text=True)
    except (OSError, subprocess.CalledProcessError):
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return None

def address_of(client):
    return str(client.get("address") or "").lower().removeprefix("0x")

def is_steam_client(client):
    kind = (client.get("class") or "").lower()
    initial = (client.get("initialClass") or "").lower()
    return kind == "steam" or initial == "steam"

def is_main_steam(client):
    if not is_steam_client(client):
        return False
    title = client.get("title") or ""
    initial_title = client.get("initialTitle") or ""
    return title == "Steam" or initial_title == "Steam"

def game_running(open_clients):
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            data = open(f"/proc/{pid}/environ", "rb").read()
        except OSError:
            continue
        if data.startswith(b"SteamAppId=") or b"\0SteamAppId=" in data:
            return True
    for client in open_clients:
        blob = ((client.get("class") or "") + " " + (client.get("initialClass") or "")).lower()
        if "steam_app_" in blob:
            return True
    return False

open_clients = clients()
if open_clients is None:
    print("keep")
    sys.exit(0)

for client in open_clients:
    if address_of(client) == closing and closing:
        continue
    if not (client.get("mapped") and not client.get("hidden")):
        continue
    if is_main_steam(client):
        print("keep")
        sys.exit(0)

if game_running(open_clients):
    print("keep")
    sys.exit(0)

print("quit")
PY
)"

if [[ "$decision" != "quit" ]]; then
  exit 0
fi

if ! pgrep -x steam >/dev/null 2>&1; then
  exit 0
fi

steam -shutdown
