#!/usr/bin/env bash
# Block until NetworkManager reports a connect or disconnect.
LOCK="${XDG_RUNTIME_DIR:-/tmp}/qs_network_wait.lock"
exec 9>"$LOCK"
if ! flock -n 9; then
    sleep 10
    exit 0
fi

# nmcli prints the current state immediately. Ignore that snapshot and
# wait for a later line so this does not exit and restart in a loop.
if timeout 90 nmcli monitor 2>/dev/null | awk '
    BEGIN { start = systime(); found = 0 }
    /connected|disconnected/ && systime() - start >= 1 { found = 1; exit }
    END { exit found ? 0 : 1 }
'; then
    exit 0
fi
sleep 10
exit 0
