#!/usr/bin/env bash
# Wake the battery poller when capacity/status changes.
# Capacity updates often skip udev events, so we poll sysfs and also listen to udev.
PIPE="/tmp/qs_battery_wait_$$.fifo"
mkfifo "$PIPE" 2>/dev/null
trap 'rm -f "$PIPE"; kill $(jobs -p) 2>/dev/null; exit 0' EXIT INT TERM

read_bat() {
    local percent status
    percent=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1)
    status=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1)
    echo "${percent:-?}|${status:-?}"
}

# Exit as soon as capacity or charging status changes.
# Capacity moves at most ~1%/minute in normal use, so a 10-second poll is
# plenty of resolution — instant transitions (AC plug/unplug) still wake via
# the udev listener below.
(
    prev=$(read_bat)
    while true; do
        sleep 10
        cur=$(read_bat)
        if [ "$cur" != "$prev" ]; then
            echo "changed" > "$PIPE"
            exit 0
        fi
    done
) &

# Instant wake on AC plug/unplug and other power_supply uevents
udevadm monitor --subsystem-match=power_supply 2>/dev/null \
    | grep --line-buffered "change" > "$PIPE" &

# Hard ceiling so a stuck waiter can't freeze the bar forever
(sleep 30 && echo "timeout" > "$PIPE") &

read -r _ < "$PIPE"
sleep 0.05
