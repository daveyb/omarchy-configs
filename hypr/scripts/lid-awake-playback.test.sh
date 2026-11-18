#!/bin/bash

script=${1:?usage: lid-awake-playback.test.sh SCRIPT}
source "$script" || exit 1

pactl_status=0
pactl_out=

pactl() {
  printf '%s' "$pactl_out"
  return "$pactl_status"
}

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

assert_playback() {
  local name=$1 want=$2 tmp status
  tmp=$(mktemp) || fail "$name failed"
  probe_playback >"$tmp"
  status=$?
  if [[ $status -ne 0 ]]; then
    rm -f "$tmp"
    fail "$name failed"
  fi
  if ! printf '%s\n' "$want" | cmp -s - "$tmp"; then
    rm -f "$tmp"
    fail "$name failed"
  fi
  rm -f "$tmp"
}

pactl_status=0
pactl_out='[{"corked":false,"properties":{"application.name":"Spotify"}}]'
assert_playback "one sink-input, corked false, application.name Spotify" 1

pactl_status=0
pactl_out='[{"corked":true,"properties":{"application.name":"Chromium"}}]'
assert_playback "one sink-input, corked true, application.name Chromium" 0

pactl_status=0
pactl_out='[{"corked":true,"properties":{"application.name":"Chromium"}},{"corked":false,"properties":{"application.name":"Spotify"}}]'
assert_playback "two inputs, one corked false" 1

pactl_status=0
pactl_out='[]'
assert_playback "empty array" 0

pactl_status=1
pactl_out=
assert_playback "pactl exits 1 and prints nothing" 0

pactl_status=0
pactl_out='[{"properties":{"application.name":"Chromium"}},{"corked":"false","properties":{"application.name":"Spotify"}},{"corked":false,"properties":{"application.name":"VLC"}}]'
assert_playback "corked missing or a string, with an uncorked sibling" 1

pactl_status=0
pactl_out='[{"properties":{"application.name":"Spotify"}},{"corked":"false"},{"corked":"true"}]'
assert_playback "corked missing or a string, only bad elements" 0

pactl_status=0
pactl_out='not-json'
assert_playback "non-JSON" 0
