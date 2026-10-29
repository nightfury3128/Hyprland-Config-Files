#!/usr/bin/env bash
# power-monitor.sh — battery-aware idle + compositor tuning.
# Switches hypridle config and toggles Hyprland eye-candy based on AC/battery.
# Never touches brightness. On battery, heavy helpers are stopped.

HYPRIDLE_BIN=$(command -v hypridle 2>/dev/null)
AC_CONF="$HOME/.config/hypr/hypridle-ac.conf"
BATTERY_CONF="$HOME/.config/hypr/hypridle-battery.conf"
GEO_TZ="$HOME/.config/hypr/scripts/geo_timezone.sh"

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

apply_hypridle() {
    local conf="$1"
    [ -z "$HYPRIDLE_BIN" ] && return
    pkill -x hypridle 2>/dev/null
    sleep 0.2
    if [ -f "$conf" ]; then
        "$HYPRIDLE_BIN" -c "$conf" >/dev/null 2>&1 &
    else
        "$HYPRIDLE_BIN" >/dev/null 2>&1 &
    fi
    disown
}

# Hyprland 0.56 rejects `hyprctl keyword` (Lua config). Brightness is never set.
hypr_eval() {
    command -v hyprctl >/dev/null 2>&1 || return
    hyprctl eval "$1" >/dev/null 2>&1 || true
}

apply_qs_layer() {
    local blur="$1"
    local no_anim="$2"
    hypr_eval "hl.layer_rule({ name = \"blur-quickshell\", match = { namespace = \"quickshell\" }, blur = ${blur}, no_anim = ${no_anim} })"
}

apply_hyprctl_ac() {
    hypr_eval 'hl.config({ animations = { enabled = true }, decoration = { blur = { enabled = true, size = 6, passes = 1 }, shadow = { enabled = true }, active_opacity = 0.92, inactive_opacity = 0.82 }, misc = { vrr = 0 } })'
    apply_qs_layer true false
}

apply_hyprctl_battery() {
    hypr_eval 'hl.config({ animations = { enabled = false }, decoration = { blur = { enabled = false }, shadow = { enabled = false }, active_opacity = 1.0, inactive_opacity = 1.0 }, misc = { vrr = 0 } })'
    apply_qs_layer false true
}

stop_heavy_helpers() {
    pkill -f "speedtest_daemon.sh" >/dev/null 2>&1 || true
    pkill -x mpvpaper >/dev/null 2>&1 || true
    pkill -x cliphist >/dev/null 2>&1 || true
    pkill -f "cliphist store" >/dev/null 2>&1 || true
}

start_geo_tz() {
    [ -x "$GEO_TZ" ] || return
    pgrep -f "geo_timezone.sh" >/dev/null 2>&1 && return
    "$GEO_TZ" >/dev/null 2>&1 &
    disown
}

stop_geo_tz() {
    pkill -f "geo_timezone.sh" 2>/dev/null
}

current_mode=""
set_mode() {
    local new_mode="$1"
    [ "$new_mode" = "$current_mode" ] && return
    current_mode="$new_mode"
    if [ "$new_mode" = "ac" ]; then
        apply_hypridle "$AC_CONF"
        apply_hyprctl_ac
        start_geo_tz
    else
        apply_hypridle "$BATTERY_CONF"
        apply_hyprctl_battery
        stop_geo_tz
        stop_heavy_helpers
    fi
}

refresh() {
    if is_on_ac; then set_mode "ac"; else set_mode "battery"; fi
}

refresh

# Event-driven: block on udev power_supply changes; debounce bursts.
# If udevadm dies, back off and retry — a low-frequency wall-clock
# refresh below still catches missed transitions.
udev_loop() {
    while :; do
        udevadm monitor --subsystem-match=power_supply 2>/dev/null \
            | while IFS= read -r line; do
                case "$line" in
                    *change*)
                        sleep 0.5
                        refresh
                        ;;
                esac
            done
        sleep 30
    done
}

udev_loop &
UDEV_PID=$!
trap 'kill "$UDEV_PID" 2>/dev/null' EXIT INT TERM

# Wall-clock safety net for missed events (15 min is fine — udev
# handles real transitions in under a second).
while :; do
    sleep 900
    refresh
done
