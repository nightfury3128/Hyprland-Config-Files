#!/usr/bin/env bash
# power-monitor.sh — battery-aware idle management
# Starts hypridle with AC or battery config and switches when power state changes.

HYPRIDLE_BIN=$(command -v hypridle 2>/dev/null)
AC_CONF="$HOME/.config/hypr/hypridle-ac.conf"
BATTERY_CONF="$HOME/.config/hypr/hypridle-battery.conf"

[ -z "$HYPRIDLE_BIN" ] && exit 0

is_on_ac() {
    local online
    for online in /sys/class/power_supply/*/online; do
        [ -r "$online" ] || continue
        case "$online" in
            *BAT*|*bat*) continue ;;
        esac
        [ "$(cat "$online" 2>/dev/null)" = "1" ] && return 0
    done
    return 1
}

apply_config() {
    local conf="$1"
    pkill -x hypridle 2>/dev/null
    sleep 0.2
    if [ -f "$conf" ]; then
        "$HYPRIDLE_BIN" -c "$conf" >/dev/null 2>&1 &
    else
        "$HYPRIDLE_BIN" >/dev/null 2>&1 &
    fi
    disown
}

current_mode=""
set_mode() {
    local new_mode="$1"
    [ "$new_mode" = "$current_mode" ] && return
    current_mode="$new_mode"
    if [ "$new_mode" = "ac" ]; then
        apply_config "$AC_CONF"
    else
        apply_config "$BATTERY_CONF"
    fi
}

if is_on_ac; then
    set_mode "ac"
else
    set_mode "battery"
fi

udevadm monitor --subsystem-match=power_supply 2>/dev/null \
    | while IFS= read -r line; do
        case "$line" in
            *"change"*)
                sleep 0.5
                if is_on_ac; then
                    set_mode "ac"
                else
                    set_mode "battery"
                fi
                ;;
        esac
    done
