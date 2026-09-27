#!/usr/bin/env bash

# --- CONFIGURATION ---
# Set to 'true' to hide unpaired devices that only broadcast a MAC address (filters out public BLE spam).
# Set to 'false' if you are trying to pair a stubborn new device that won't show its name.
STRICT_SPAM_FILTER=true
# ---------------------

# Use XDG_RUNTIME_DIR if available for ram-backed speed, else fallback to ~/.cache
CACHE_DIR="${XDG_RUNTIME_DIR:-$HOME/.cache}/quickshell_network_cache"
mkdir -p "$CACHE_DIR"
PID_FILE="$CACHE_DIR/bt_scan_pid"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENSURE_A2DP="$SCRIPT_DIR/../librepods/ensure_a2dp.sh"
LIBREPODS_FETCH="$SCRIPT_DIR/../watchers/librepods_fetch.sh"

get_icon() {
    local type="${1,,}"
    local name="${2,,}"
    if [[ "$type" == *"headset"* || "$type" == *"headphone"* || "$name" == *"headphone"* || "$name" == *"buds"* || "$name" == *"pods"* ]]; then echo "🎧"
    elif [[ "$type" == *"audio"* || "$type" == *"speaker"* || "$type" == *"card"* || "$name" == *"speaker"* ]]; then echo "蓼"
    elif [[ "$type" == *"phone"* || "$name" == *"phone"* || "$name" == *"iphone"* || "$name" == *"android"* ]]; then echo ""
    elif [[ "$type" == *"mouse"* || "$name" == *"mouse"* ]]; then echo ""
    elif [[ "$type" == *"keyboard"* || "$name" == *"keyboard"* ]]; then echo ""
    elif [[ "$type" == *"controller"* || "$name" == *"controller"* ]]; then echo ""
    else echo ""
    fi
}

get_audio_profile() {
    local mac="$1"
    local mac_us="${mac//:/_}"

    local active=$(pactl list cards 2>/dev/null | awk -v mac="$mac_us" '
        tolower($0) ~ "name:.*"tolower(mac) { found=1 }
        found && tolower($0) ~ "active profile:" {
            sub(/.*Active Profile: /, ""); print; exit
        }
        found && /^$/ { exit }
    ')

    if [[ -z "$active" || "$active" == "off" ]]; then echo "None"; return; fi

    if [[ "$active" == *"a2dp"* ]]; then echo "Hi-Fi (A2DP)"; return; fi
    if [[ "$active" == *"headset"* || "$active" == *"hfp"* ]]; then echo "Headset (HFP)"; return; fi

    echo "Connected"
}

# True iff bluetoothctl currently reports Connected: yes for this MAC.
is_connected() {
    local mac="$1"
    timeout 1 bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"
}

get_status() {
    power="off"
    if bluetoothctl show | grep -q "Powered: yes"; then power="on"; fi

    connected_json="[]"
    devices_json="[]"

    if [ "$power" == "on" ]; then
        paired_macs=$(bluetoothctl devices Paired)
        mapfile -t devices < <(bluetoothctl devices)
        mapfile -t connected_info_lines < <(bluetoothctl devices Connected)

        # AirPods don't report battery via standard bluez BAS — pull from
        # librepods once per status call and merge below.
        librepods_json=""
        librepods_mac=""
        if [ -x "$LIBREPODS_FETCH" ]; then
            librepods_json=$(timeout 1 "$LIBREPODS_FETCH" 2>/dev/null || echo "")
            if [ -n "$librepods_json" ] && echo "$librepods_json" | jq -e '.connected == true' >/dev/null 2>&1; then
                librepods_mac=$(echo "$librepods_json" | jq -r '.address // empty' | tr '[:lower:]' '[:upper:]')
            else
                librepods_json=""
            fi
        fi

        connected_macs=""
        connected_list_objs=()
        devices_list_objs=()

        # 1. PROCESS CONNECTED DEVICES
        for c_line in "${connected_info_lines[@]}"; do
            [ -z "$c_line" ] && continue
            rest="${c_line#Device }"
            mac="${rest%% *}"
            name="${rest#* }"
            connected_macs+="$mac "

            CACHE_FILE="$CACHE_DIR/bt_stat_${mac//:/_}"

            # Name and icon are stable; profile changes on reconnect so it is
            # not cached — always ask pactl for the live value.
            if [ -f "$CACHE_FILE" ]; then
                source "$CACHE_FILE"
            else
                info=$(bluetoothctl info "$mac")
                icon_type=$(echo "$info" | awk -F': ' '/Icon:/ {print $2}')
                icon=$(get_icon "$icon_type" "$name")

                echo "CACHE_NAME=\"${name//\"/\\\"}\"" > "$CACHE_FILE"
                echo "CACHE_ICON=\"${icon//\"/\\\"}\"" >> "$CACHE_FILE"

                CACHE_NAME="${name//\"/\\\"}"
                CACHE_ICON="${icon//\"/\\\"}"
            fi
            live_profile=$(get_audio_profile "$mac")
            CACHE_PROFILE="${live_profile//\"/\\\"}"

            bat=$(bluetoothctl info "$mac" | awk -F'[(|)]' '/Battery Percentage:/ {print $2}')
            [ -z "$bat" ] && bat="0"

            # Override with librepods data if this MAC matches AirPods.
            extra_fields=""
            mac_upper="${mac^^}"
            if [ -n "$librepods_json" ] && [ "$mac_upper" = "$librepods_mac" ]; then
                lp_pct=$(echo "$librepods_json" | jq -r '.percent // 0')
                [ "$lp_pct" != "0" ] && [ -n "$lp_pct" ] && bat="$lp_pct"
                lp_left=$(echo "$librepods_json" | jq -r '.left // 0')
                lp_right=$(echo "$librepods_json" | jq -r '.right // 0')
                lp_case=$(echo "$librepods_json" | jq -r '.case // 0')
                lp_left_avail=$(echo "$librepods_json" | jq -r '.left_available // false')
                lp_right_avail=$(echo "$librepods_json" | jq -r '.right_available // false')
                lp_case_avail=$(echo "$librepods_json" | jq -r '.case_available // false')
                lp_noise=$(echo "$librepods_json" | jq -r '.noise // "off"')
                extra_fields=",\"left\":$lp_left,\"right\":$lp_right,\"case\":$lp_case,\"leftAvailable\":$lp_left_avail,\"rightAvailable\":$lp_right_avail,\"caseAvailable\":$lp_case_avail,\"noise\":\"$lp_noise\""
            fi

            connected_list_objs+=("{\"id\":\"$mac\",\"name\":\"$CACHE_NAME\",\"mac\":\"$mac\",\"icon\":\"$CACHE_ICON\",\"battery\":\"$bat\",\"profile\":\"$CACHE_PROFILE\",\"connected\":true$extra_fields}")
        done

        if [ ${#connected_list_objs[@]} -gt 0 ]; then
            connected_json="[$(IFS=,; echo "${connected_list_objs[*]}")]"
        fi

        # 2. PROCESS DISCOVERED & PAIRED DEVICES
        # connected_macs comes from the same bluetoothctl invocation as the
        # connected list above, so this filter is authoritative within one
        # get_status call and won't race with a stale QML-side cache.
        for line in "${devices[@]}"; do
            [ -z "$line" ] && continue
            rest="${line#Device }"
            mac="${rest%% *}"

            if [[ "$connected_macs" == *"$mac"* ]]; then continue; fi

            name="${rest#* }"
            name_esc="${name//\"/\\\"}"

            if [[ "$paired_macs" == *"$mac"* ]]; then
                action="Connect"
            else
                action="Pair"

                # --- CONFIGURABLE SPAM FILTER ---
                if [[ "$STRICT_SPAM_FILTER" == true ]]; then
                    mac_hyphens="${mac//:/-}"
                    if [[ "$name" == "$mac" || "$name" == "$mac_hyphens" || -z "$name" ]]; then
                        continue
                    fi
                fi
            fi

            icon=$(get_icon "unknown" "$name")
            icon_esc="${icon//\"/\\\"}"

            devices_list_objs+=("{\"id\":\"$mac\",\"name\":\"$name_esc\",\"mac\":\"$mac\",\"icon\":\"$icon_esc\",\"action\":\"$action\",\"connected\":false}")
        done

        if [ ${#devices_list_objs[@]} -gt 0 ]; then
            devices_json="[$(IFS=,; echo "${devices_list_objs[*]}")]"
        fi
    fi

    echo "{\"power\":\"$power\",\"connected\":$connected_json,\"devices\":$devices_json}"
}

toggle_power() {
    if bluetoothctl show | grep -q "Powered: yes"; then
        bluetoothctl power off
    else
        bluetoothctl power on
    fi
    sleep 0.5
}

connect_dev() {
    local mac="$1"
    [ -z "$mac" ] && return 1

    if [ -f "$PID_FILE" ]; then kill -STOP $(cat "$PID_FILE") 2>/dev/null; fi

    # If bluez already thinks the device is connected but audio isn't routing
    # (the classic "I toggled BT off/on and it worked" pattern), a plain
    # `bluetoothctl connect` is often silently rejected. Force a clean
    # reconnect and drop any stale profile cache.
    if is_connected "$mac"; then
        rm -f "$CACHE_DIR/bt_stat_${mac//:/_}" 2>/dev/null
        bluetoothctl disconnect "$mac" >/dev/null 2>&1
        for _ in 1 2 3 4 5 6 7 8; do
            is_connected "$mac" || break
            sleep 0.25
        done
    fi

    bluetoothctl trust "$mac" > /dev/null 2>&1
    bluetoothctl connect "$mac"
    connect_rc=$?

    if [ $connect_rc -eq 0 ]; then
        for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
            is_connected "$mac" && break
            sleep 0.25
        done
        sleep 0.3
        if [ -x "$ENSURE_A2DP" ]; then
            timeout 3 "$ENSURE_A2DP" "$mac" >/dev/null 2>&1 || true
        fi
    fi

    if [ -f "$PID_FILE" ]; then kill -CONT $(cat "$PID_FILE") 2>/dev/null; fi
    return $connect_rc
}

disconnect_dev() {
    local mac="$1"
    rm -f "$CACHE_DIR/bt_stat_${mac//:/_}" 2>/dev/null
    bluetoothctl disconnect "$mac"
}

cmd="$1"
case $cmd in
    --status) get_status ;;
    --toggle) toggle_power ;;
    --connect) connect_dev "$2" ;;
    --disconnect) disconnect_dev "$2" ;;
esac
