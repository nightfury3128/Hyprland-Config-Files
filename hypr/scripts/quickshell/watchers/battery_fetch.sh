#!/usr/bin/env bash
# Shared battery snapshot for TopBar + BatteryPopup.
get_battery_dir() { ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1; }
get_battery_percent() { cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1 || echo "100"; }
get_battery_status() { cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1 || echo "Full"; }
get_battery_health() {
    local bat full design
    bat=$(get_battery_dir)
    [ -z "$bat" ] && { echo "0"; return; }
    full=$(cat "$bat/energy_full" 2>/dev/null || cat "$bat/charge_full" 2>/dev/null || echo 0)
    design=$(cat "$bat/energy_full_design" 2>/dev/null || cat "$bat/charge_full_design" 2>/dev/null || echo 0)
    if [ "$design" -gt 0 ] 2>/dev/null; then
        echo $(( full * 100 / design ))
    else
        echo "0"
    fi
}
get_battery_icon() {
    local percent status
    percent=$(get_battery_percent)
    status=$(get_battery_status)
    if [ "$status" = "Charging" ] || [ "$status" = "Full" ]; then
        if [ "$percent" -ge 90 ]; then echo "󰂅"
        elif [ "$percent" -ge 80 ]; then echo "󰂋"
        elif [ "$percent" -ge 60 ]; then echo "󰂊"
        elif [ "$percent" -ge 40 ]; then echo "󰢞"
        elif [ "$percent" -ge 20 ]; then echo "󰂆"
        else echo "󰢜"; fi
    else
        if [ "$percent" -ge 90 ]; then echo "󰁹"
        elif [ "$percent" -ge 80 ]; then echo "󰂂"
        elif [ "$percent" -ge 70 ]; then echo "󰂁"
        elif [ "$percent" -ge 60 ]; then echo "󰂀"
        elif [ "$percent" -ge 50 ]; then echo "󰁿"
        elif [ "$percent" -ge 40 ]; then echo "󰁾"
        elif [ "$percent" -ge 30 ]; then echo "󰁽"
        elif [ "$percent" -ge 20 ]; then echo "󰁼"
        elif [ "$percent" -ge 10 ]; then echo "󰁻"
        else echo "󰁺"; fi
    fi
}
jq -n -c \
    --arg percent "$(get_battery_percent)" \
    --arg status "$(get_battery_status)" \
    --arg icon "$(get_battery_icon)" \
    --arg health "$(get_battery_health)" \
    '{percent: $percent, status: $status, icon: $icon, health: $health}'
