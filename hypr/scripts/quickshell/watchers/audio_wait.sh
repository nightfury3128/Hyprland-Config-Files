#!/usr/bin/env bash
# Block until the next sink/server event, then exit so the bar refetches.
# A dead pactl or a second waiter sleeps before returning so the bar cannot spin.
LOCK="${XDG_RUNTIME_DIR:-/tmp}/qs_audio_wait.lock"
exec 9>"$LOCK"
if ! flock -n 9; then
    sleep 8
    exit 0
fi

if timeout 90 pactl subscribe 2>/dev/null | grep -m1 -E 'sink|server' >/dev/null; then
    exit 0
fi
sleep 8
exit 0
