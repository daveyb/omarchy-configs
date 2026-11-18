#!/bin/bash

# id|release|tail_s|probe|lid_when_live|why
# The monitor tail exists so a USB-C connector blip does not suspend a closed laptop.
REASON_ROWS=(
  'monitor|tail|15|probe_monitor|stock|external monitor connected'
  'playback|tail|15|probe_playback|playback-dark|audio playing'
)

declare -A snap
declare -A mem_lost_at
declare -A mem_prev

inhibit_pid=""
last_holding_ids=""
DAEMON_LOCK="${XDG_RUNTIME_DIR:-/tmp}/omarchy-lid-awake.lock"
PLAYBACK_DARK_FLAG="${XDG_RUNTIME_DIR:-/tmp}/omarchy-lid-awake.playback-dark"
INTERVAL=2

dec_hold=0
dec_why=""
dec_holding_ids=""
dec_screen=stock
now=0

probe_monitor() {
  if omarchy-hw-external-monitors >/dev/null 2>&1; then
    printf '1\n'
  else
    printf '0\n'
  fi
}

parse_audible_streams() {
  jq -r '
    if type == "array" then
      .[]
      | select(.corked | type == "boolean")
      | if .corked == false then "1" else "0" end
    else
      empty
    end
  ' 2>/dev/null || true
}

streams_any_live() {
  local line live=0
  while IFS= read -r line || [[ -n $line ]]; do
    if [[ $line == "1" ]]; then
      live=1
    fi
  done
  if (( live )); then
    printf '1\n'
  else
    printf '0\n'
  fi
  return 0
}

probe_playback() {
  local json
  json=$(pactl -f json list sink-inputs 2>/dev/null) || json='[]'
  if [[ -z $json ]]; then
    json='[]'
  fi
  printf '%s\n' "$json" | parse_audible_streams | streams_any_live
  return 0
}

read_snapshot() {
  local row id release tail_s probe lid_when_live why val
  for row in "${REASON_ROWS[@]}"; do
    IFS='|' read -r id release tail_s probe lid_when_live why <<<"$row"
    val=$("$probe" 2>/dev/null) || true
    val=${val//[[:space:]]/}
    if [[ $val == 1 ]]; then
      snap[$id]=1
    else
      snap[$id]=0
    fi
  done
}

decide() {
  local row id release tail_s probe lid_when_live why live lost prev holding
  dec_hold=0
  dec_why=""
  dec_holding_ids=""
  for row in "${REASON_ROWS[@]}"; do
    IFS='|' read -r id release tail_s probe lid_when_live why <<<"$row"
    live=${snap[$id]:-0}
    lost=${mem_lost_at[$id]:-0}
    prev=${mem_prev[$id]:-0}
    if (( live )); then
      lost=0
    elif [[ $release == tail ]] && (( prev )) && (( lost == 0 )); then
      lost=$now
    elif (( lost > 0 )) && (( now - lost >= tail_s )); then
      lost=0
    fi
    holding=0
    if (( live )) || (( lost > 0 )); then
      holding=1
    fi
    mem_lost_at[$id]=$lost
    mem_prev[$id]=$live
    if (( holding )); then
      dec_hold=1
      dec_holding_ids="${dec_holding_ids:+$dec_holding_ids }$id"
      [[ -z $dec_why ]] && dec_why=$why
    fi
  done
}

screen_action() {
  local row id release tail_s probe lid_when_live why chosen
  dec_screen=stock
  chosen=0
  for row in "${REASON_ROWS[@]}"; do
    IFS='|' read -r id release tail_s probe lid_when_live why <<<"$row"
    if (( ! chosen )) && (( snap[$id] )); then
      dec_screen=$lid_when_live
      chosen=1
    fi
  done
}

inhibit_alive() {
  local state
  [[ -n $inhibit_pid ]] || return 1
  kill -0 "$inhibit_pid" 2>/dev/null || return 1
  state=$(ps -o state= -p "$inhibit_pid" 2>/dev/null) || return 1
  state=${state//[[:space:]]/}
  [[ -n $state && ${state:0:1} != Z ]]
}

hold_inhibitor() {
  if inhibit_alive; then
    return 0
  fi
  if [[ -n $inhibit_pid ]]; then
    wait "$inhibit_pid" 2>/dev/null || true
    inhibit_pid=""
  fi
  systemd-inhibit --what=handle-lid-switch --who=omarchy-lid-awake \
    --why="$dec_why" --mode=block sleep infinity &
  inhibit_pid=$!
  logger -t omarchy-lid-awake -- "lid close will not suspend (inhibit pid $inhibit_pid)"
}

drop_inhibitor() {
  [[ -n $inhibit_pid ]] || return 0
  kill "$inhibit_pid" 2>/dev/null || true
  wait "$inhibit_pid" 2>/dev/null || true
  logger -t omarchy-lid-awake -- "lid close can suspend again"
  inhibit_pid=""
}

apply_inhibitor() {
  if [[ $dec_holding_ids != "$last_holding_ids" ]]; then
    logger -t omarchy-lid-awake -- "$dec_holding_ids" || true
    last_holding_ids=$dec_holding_ids
  fi
  if (( dec_hold )); then
    hold_inhibitor
  else
    drop_inhibitor
  fi
}

dpms_internal() {
  local action=$1 name
  name=$(omarchy-hyprland-monitor-laptop 2>/dev/null) || true
  if [[ -z $name || ! $name =~ ^[A-Za-z0-9._-]+$ ]]; then
    logger -t omarchy-lid-awake -- "internal monitor name unusable"
    return 0
  fi
  hyprctl dispatch "hl.dsp.dpms({ action = \"$action\", monitor = \"$name\" })"
}

arm_playback_dark() {
  local tmp dir
  dir=${PLAYBACK_DARK_FLAG%/*}
  tmp=$(mktemp "$dir/omarchy-lid-awake.playback-dark.XXXXXX" 2>/dev/null) || tmp=""
  if [[ -n $tmp ]]; then
    mv -f "$tmp" "$PLAYBACK_DARK_FLAG"
  else
    : >"$PLAYBACK_DARK_FLAG"
  fi
  dpms_internal disable
  omarchy-brightness-keyboard --no-osd off || true
}

clear_playback_dark() {
  [[ -e $PLAYBACK_DARK_FLAG ]] || return 0
  dpms_internal enable
  omarchy-brightness-keyboard --no-osd restore || true
  rm -f -- "$PLAYBACK_DARK_FLAG"
}

lid_close() {
  read_snapshot
  screen_action
  if [[ $dec_screen == stock ]]; then
    rm -f -- "$PLAYBACK_DARK_FLAG"
    exec /usr/bin/omarchy-system-lid-close
  fi
  if [[ $dec_screen == playback-dark ]]; then
    arm_playback_dark
    return 0
  fi
}

lid_open() {
  clear_playback_dark
  exec /usr/bin/omarchy-hyprland-monitor-clamshell
}

run_daemon() {
  local row id release tail_s probe lid_when_live why
  exec 9>"$DAEMON_LOCK"
  flock -n 9 || exit 0
  trap 'drop_inhibitor; exit 0' EXIT INT TERM
  logger -t omarchy-lid-awake -- "watching lid stay-awake reasons"
  inhibit_pid=""
  last_holding_ids=""
  for row in "${REASON_ROWS[@]}"; do
    IFS='|' read -r id release tail_s probe lid_when_live why <<<"$row"
    mem_lost_at[$id]=0
    mem_prev[$id]=0
  done
  while true; do
    read_snapshot
    now=$(date +%s)
    decide
    apply_inhibitor
    sleep "$INTERVAL"
  done
}

main() {
  case ${1:-} in
    lid-close) lid_close ;;
    lid-open) lid_open ;;
    "") run_daemon ;;
    *) logger -t omarchy-lid-awake -- "unknown argument"; exit 2 ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
