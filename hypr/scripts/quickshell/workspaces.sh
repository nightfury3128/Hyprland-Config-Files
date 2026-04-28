#!/usr/bin/env bash

# ============================================================================
# 1. ZOMBIE PREVENTION
# Kills any older instances of this script. When Quickshell reloads, 
# it can leave the old listener pipelines running in the background infinitely.
# ============================================================================
for pid in $(pgrep -f "quickshell/workspaces.sh"); do
    if [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ]; then
        kill -9 "$pid" 2>/dev/null
    fi
done

# Cleanly kill immediate children (like socat) when the script exits normally
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

# ============================================================================
# 2. THE EVENT DEBOUNCER
# Listen to Hyprland socket wrapped in an infinite loop
# ============================================================================
while true; do
    socat -u UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock - | while read -r line; do
        case "$line" in
            workspace*|focusedmon*|activewindow*|createwindow*|closewindow*|movewindow*|destroyworkspace*)
                
                # -> THE FIX <-
                # Hyprland emits HUNDREDS of events a second when you move/resize windows.
                # This reads and discards all subsequent events arriving within a 50ms window.
                # It bundles the storm into a single UI update, completely preventing CPU clogging!
                while read -t 0.05 -r extra_line; do
                    continue
                done

                print_workspaces
                ;;
        esac
    done
    sleep 1
done
