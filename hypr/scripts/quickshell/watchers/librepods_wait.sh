#!/usr/bin/env bash
# Wake the LibrePods poller on Bluetooth device changes, with a short fallback timeout.
PIPE="/tmp/qs_librepods_wait_$$.fifo"
mkfifo "$PIPE" 2>/dev/null
trap 'rm -f "$PIPE"; kill $(jobs -p) 2>/dev/null; exit 0' EXIT INT TERM

dbus-monitor --system "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.bluez.Device1'" 2>/dev/null \
    | grep --line-buffered -E 'string "(Connected|Percentage)"' > "$PIPE" &

(sleep 5 && echo "timeout" > "$PIPE") &

read -r _ < "$PIPE"
sleep 0.05
