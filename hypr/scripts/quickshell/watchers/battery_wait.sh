#!/usr/bin/env bash
# Slow poll. udev power_supply events fire on every capacity tick while
# charging, which used to restart this waiter in a tight loop.
# Brightness is not read or written here.
LOCK="${XDG_RUNTIME_DIR:-/tmp}/qs_battery_wait.lock"
exec 9>"$LOCK"
if ! flock -n 9; then
    sleep 20
    exit 0
fi

status=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1)
case "$status" in
    Charging|Full|"Not charging")
        sleep 60
        ;;
    *)
        sleep 30
        ;;
esac
exit 0
