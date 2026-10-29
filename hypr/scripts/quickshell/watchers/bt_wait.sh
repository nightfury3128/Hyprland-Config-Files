#!/usr/bin/env bash
# Block until BlueZ reports a device connect or adapter power change.
LOCK="${XDG_RUNTIME_DIR:-/tmp}/qs_bt_wait.lock"
exec 9>"$LOCK"
if ! flock -n 9; then
    sleep 10
    exit 0
fi

if timeout 90 dbus-monitor --system \
    "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.bluez.Device1'" \
    "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.bluez.Adapter1'" \
    2>/dev/null | grep -m1 -E 'string "(Connected|Powered)"' >/dev/null; then
    exit 0
fi
sleep 10
exit 0
