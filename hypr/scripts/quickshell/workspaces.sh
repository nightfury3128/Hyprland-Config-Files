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
BT_PID_FILE="$HOME/.cache/bt_scan_pid"

if [ -f "$BT_PID_FILE" ]; then
    kill $(cat "$BT_PID_FILE") 2>/dev/null
    rm -f "$BT_PID_FILE"
fi

(timeout 2 bluetoothctl scan off > /dev/null 2>&1) &

print_workspaces() {
    spaces=$(timeout 2 hyprctl workspaces -j 2>/dev/null)
    monitors=$(timeout 2 hyprctl monitors -j 2>/dev/null)

    if [ -z "$spaces" ] || [ -z "$monitors" ]; then return; fi

    global_active=$(echo "$monitors" | jq '[.[] | select(.focused)][0].activeWorkspace.id')

    if [ -z "$global_active" ] || [ "$global_active" = "null" ]; then return; fi

    # label == id always (never array position). Visible workspaces on other
    # monitors stay "occupied" so every bar shows the same 1..N numbering.
    echo "$spaces" | jq --unbuffered \
        --argjson a "$global_active" \
        --argjson monitors "$monitors" \
        -c '
        ($monitors | map(.activeWorkspace.id)) as $visible |
        sort_by(.id) | map(
            {
                id:      .id,
                label:   .id,
                monitor: .monitor,
                state:   (
                    if (.id == $a) then "active"
                    elif ([$visible[] == .id] | any) then "occupied"
                    elif (.windows // 0) > 0 then "occupied"
                    else "empty"
                    end
                ),
                tooltip: (.lastwindowtitle // "Empty")
            }
        )
    ' > /tmp/qs_workspaces.tmp

    mv /tmp/qs_workspaces.tmp /tmp/qs_workspaces.json
}

print_workspaces

backoff=1
while true; do
    started=$(date +%s)
    socat -u UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" - | while read -r line; do
        case "$line" in
            workspace*|focusedmon*|activewindow*|createwindow*|closewindow*|movewindow*|destroyworkspace*)
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
