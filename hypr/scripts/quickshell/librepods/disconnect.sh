#!/usr/bin/env bash
# Disconnect AirPods via BlueZ (+ LibrePods IPC). Finds MAC from arg, status, or paired devices.

set -euo pipefail

MAC="${1:-}"

is_airpods_info() {
    echo "$1" | grep -qiE 'AirPods|74ec2172-0bad-4d01-8f77-997b2be0722a'
}

find_airpods_mac() {
    local line mac info
    # Prefer currently connected
    while IFS= read -r line; do
        mac=$(awk '{print $2}' <<<"$line")
        [ -z "$mac" ] && continue
        info=$(timeout 1 bluetoothctl info "$mac" 2>/dev/null || true)
        if is_airpods_info "$info"; then
            echo "$mac"
            return 0
        fi
    done < <(timeout 2 bluetoothctl devices Connected 2>/dev/null || true)

    # Fall back to any paired AirPods
    while IFS= read -r line; do
        mac=$(awk '{print $2}' <<<"$line")
        [ -z "$mac" ] && continue
        info=$(timeout 1 bluetoothctl info "$mac" 2>/dev/null || true)
        if is_airpods_info "$info"; then
            echo "$mac"
            return 0
        fi
    done < <(timeout 2 bluetoothctl devices 2>/dev/null || true)
    return 1
}

if [ -z "$MAC" ] || [ "$MAC" = "null" ]; then
    CTL="${LIBREPODS_CTL:-$HOME/librepods/linux/build/librepods-ctl}"
    if [ -x "$CTL" ]; then
        MAC=$(timeout 0.8 "$CTL" status 2>/dev/null | jq -r '.address // empty' 2>/dev/null || true)
    fi
fi

if [ -z "$MAC" ] || [ "$MAC" = "null" ]; then
    MAC=$(find_airpods_mac) || true
fi

# Last-known default from LibrePods settings
if [ -z "$MAC" ] || [ "$MAC" = "null" ]; then
    MAC=$(grep -m1 '^bluetoothAddress=' "$HOME/.config/AirPodsTrayApp/AirPodsTrayApp.conf" 2>/dev/null | cut -d= -f2- || true)
fi

if [ -z "$MAC" ] || [ "$MAC" = "null" ]; then
    echo "No AirPods MAC found" >&2
    exit 1
fi

CTL="${LIBREPODS_CTL:-$HOME/librepods/linux/build/librepods-ctl}"
if [ -x "$CTL" ]; then
    timeout 3 "$CTL" disconnect >/dev/null 2>&1 || true
fi

timeout 5 bluetoothctl disconnect "$MAC" >/dev/null 2>&1 || bluetoothctl disconnect "$MAC" || true
echo "disconnected $MAC"
