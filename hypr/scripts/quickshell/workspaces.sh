#!/usr/bin/env bash

# One listener. A Quickshell reload used to spawn another copy and the two
# would kill -9 each other in a tight loop. flock keeps a single owner.
LOCK="${XDG_RUNTIME_DIR:-/tmp}/qs_workspaces.lock"
exec 9>"$LOCK"
if ! flock -n 9; then
    exit 0
fi

cleanup() {
    pkill -P $$ 2>/dev/null
}
trap cleanup EXIT SIGTERM SIGINT

# --- Special Cleanup for Network/Bluetooth ---
# The network toggle starts a background bluetooth scan that must be killed explicitly.
BT_PID_FILE="$HOME/.cache/bt_scan_pid"

if [ -f "$BT_PID_FILE" ]; then
    kill $(cat "$BT_PID_FILE") 2>/dev/null
    rm -f "$BT_PID_FILE"
fi

# Ensure bluetooth scan is explicitly turned off (timeout prevents deadlocks on fresh installs)
(timeout 2 bluetoothctl scan off > /dev/null 2>&1) &
# ---------------------------------------------

print_workspaces() {
    # Get raw data with a timeout fallback
    spaces=$(timeout 2 hyprctl workspaces -j 2>/dev/null)
    monitors=$(timeout 2 hyprctl monitors -j 2>/dev/null)

    # Failsafe if hyprctl crashes
    if [ -z "$spaces" ] || [ -z "$monitors" ]; then return; fi

    # Active = focused monitor's current workspace
    # Visible = any monitor's current workspace (shown as occupied so they look distinct)
    active=$(echo "$monitors" | jq '[.[] | select(.focused)][0].activeWorkspace.id')
    visible=$(echo "$monitors" | jq '[.[] | .activeWorkspace.id]')

    if [ -z "$active" ]; then return; fi

    # Iterate over only the real workspace IDs, sorted — no phantom slots
    echo "$spaces" | jq --unbuffered \
        --argjson a "$active" \
        --argjson vis "$visible" \
        -c '
        sort_by(.id) | to_entries | map(
            .key as $pos |
            .value as $ws |
            ($ws.id == $a)               as $isActive  |
            ([$vis[] == $ws.id] | any)   as $isVisible |
            {
                id:      $ws.id,
                label:   ($pos + 1),
                state:   (if $isActive  then "active"
                          elif $isVisible then "occupied"
                          elif $ws.windows > 0 then "occupied"
                          else "empty" end),
                tooltip: ($ws.lastwindowtitle // "Empty")
            }
        )
    ' > /tmp/qs_workspaces.tmp

    mv /tmp/qs_workspaces.tmp /tmp/qs_workspaces.json
}

# Print initial state
print_workspaces

# Reconnect with backoff. A missing socket used to make socat exit and the
# outer loop restart it with no delay, pegging a core.
backoff=1
while true; do
    started=$(date +%s)
    socat -u UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" - | while read -r line; do
        case "$line" in
            workspace*|focusedmon*|activewindow*|createwindow*|closewindow*|movewindow*|destroyworkspace*)
                # Hyprland emits bursts while moving or resizing. Drain them
                # so the bar updates once per burst.
                while read -t 0.05 -r extra_line; do
                    :
                done

                print_workspaces
                ;;
        esac
    done

    now=$(date +%s)
    if [ $((now - started)) -ge 5 ]; then
        backoff=1
    fi
    sleep "$backoff"
    if [ "$backoff" -lt 30 ]; then
        backoff=$((backoff * 2))
    fi
done
