#!/usr/bin/env bash

set -u

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Use runtime dir only if it actually exists and is writable.
if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -d "${XDG_RUNTIME_DIR:-}" ] && [ -w "${XDG_RUNTIME_DIR:-}" ]; then
    CACHE_BASE="$XDG_RUNTIME_DIR"
else
    CACHE_BASE="$HOME/.cache"
fi
CACHE_DIR="$CACHE_BASE/qs_network"
OUT_FILE="$CACHE_DIR/speedtest.json"
LOCK_FILE="$CACHE_DIR/speedtest_daemon.lock"
INTERVAL_SECONDS=5400 # 90 minutes

mkdir -p "$CACHE_DIR"

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    exit 0
fi

write_json() {
    printf '%s\n' "$1" > "$OUT_FILE.tmp"
    mv "$OUT_FILE.tmp" "$OUT_FILE"
}

run_test() {
    write_json '{"ok":false,"reason":"Running speed test...","download":0,"upload":0,"ping":0,"ts":0,"running":true}'
    result="$("$SCRIPTS_DIR/speedtest_logic.sh" 2>/dev/null)"
    if [ -z "$result" ]; then
        result='{"ok":false,"reason":"Speed test returned no data","download":0,"upload":0,"ping":0,"ts":0}'
    fi
    # Add running=false marker for popup logic.
    result="$(printf '%s' "$result" | jq -c '. + {running:false}' 2>/dev/null || printf '%s' "$result")"
    write_json "$result"
}

if [ ! -f "$OUT_FILE" ]; then
    write_json '{"ok":false,"reason":"Pending auto run...","download":0,"upload":0,"ping":0,"ts":0,"running":false}'
fi

last_ssid=""
last_run_ts=0
last_state=""

get_current_ssid() {
    nmcli -t -f active,ssid device wifi 2>/dev/null | awk -F: '$1=="yes"{print $2; exit}'
}

handle_wifi_state() {
    local now_ts
    now_ts="$(date +%s)"
    local wifi_state
    wifi_state="$(nmcli radio wifi 2>/dev/null | tr '[:upper:]' '[:lower:]')"
    local wifi_connected
    wifi_connected="$(get_current_ssid)"

    if [ "$wifi_state" = "enabled" ] && [ -n "${wifi_connected:-}" ]; then
        local need_run=0
        if [ "$wifi_connected" != "$last_ssid" ]; then
            need_run=1
        elif [ $((now_ts - last_run_ts)) -ge "$INTERVAL_SECONDS" ]; then
            need_run=1
        fi

        if [ "$need_run" -eq 1 ]; then
            run_test
            last_run_ts="$now_ts"
        fi

        last_ssid="$wifi_connected"
        last_state="connected"
    else
        if [ "$last_state" != "disconnected" ]; then
            write_json '{"ok":false,"reason":"Waiting for Wi-Fi connection","download":0,"upload":0,"ping":0,"ts":0,"running":false}'
        fi
        last_ssid=""
        last_state="disconnected"
    fi
}

# Initial sync on startup.
handle_wifi_state

# Long-interval refresh loop (kept for periodic re-tests).
(
    while true; do
        sleep "$INTERVAL_SECONDS"
        handle_wifi_state
    done
) &

# Event-driven SSID / network-state updates.
nmcli monitor 2>/dev/null | while IFS= read -r _line; do
    handle_wifi_state
done
