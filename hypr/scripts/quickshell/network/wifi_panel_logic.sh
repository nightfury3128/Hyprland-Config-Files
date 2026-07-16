#!/usr/bin/env bash

POWER=$(nmcli radio wifi)

if [[ "$POWER" == "disabled" ]]; then
    echo '{ "power": "off", "connected": null, "networks": [] }'
    exit 0
fi

get_icon() {
    local signal=$1
    if [[ $signal -ge 80 ]]; then echo "󰤨";
    elif [[ $signal -ge 60 ]]; then echo "󰤥";
    elif [[ $signal -ge 40 ]]; then echo "󰤢";
    elif [[ $signal -ge 20 ]]; then echo "󰤟";
    else echo "󰤯"; fi
}

CACHE_DIR="${XDG_RUNTIME_DIR:-$HOME/.cache}/quickshell_network_cache"
mkdir -p "$CACHE_DIR"

# Known Wi-Fi profiles: store both raw and trimmed names/SSIDs for matching.
SAVED_TMP=$(mktemp)
{
    nmcli -t -f NAME,TYPE connection show 2>/dev/null \
        | awk -F: '$2=="802-11-wireless"{print $1}'
    nmcli -t -f UUID,TYPE connection show 2>/dev/null \
        | awk -F: '$2=="802-11-wireless"{print $1}' \
        | while IFS= read -r uuid; do
            nmcli -g 802-11-wireless.ssid connection show uuid "$uuid" 2>/dev/null
          done
} | awk '
    NF {
        raw=$0
        trim=$0
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", trim)
        if (raw != "") print raw
        if (trim != "" && trim != raw) print trim
    }
' | sort -u > "$SAVED_TMP"

CURRENT_RAW=$(nmcli -t -f active,ssid,signal,security device wifi | awk -F: '$1=="yes"{print; exit}')

if [[ -n "$CURRENT_RAW" ]]; then
    IFS=':' read -r active ssid signal security <<< "$CURRENT_RAW"
    icon=$(get_icon "$signal")
    
    SAFE_SSID="${ssid//[^a-zA-Z0-9]/_}"
    CACHE_FILE="$CACHE_DIR/wifi_$SAFE_SSID"
    
    if [ -f "$CACHE_FILE" ]; then
        source "$CACHE_FILE"
    fi
    
    if [ -z "$IP" ] || [ "$IP" == "No IP" ] || [ -z "$FREQ" ]; then
        IFACE=$(nmcli -t -f DEVICE,TYPE d | awk -F: '$2=="wifi"{print $1;exit}')
        IP=$(ip -4 addr show dev "$IFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
        [ -z "$IP" ] && IP="No IP"
        
        FREQ=$(iw dev "$IFACE" link 2>/dev/null | awk '/freq:/ {print $2}')
        [ -n "$FREQ" ] && FREQ="${FREQ} MHz" || FREQ="Unknown"
        
        echo "IP=\"$IP\"" > "$CACHE_FILE"
        echo "FREQ=\"$FREQ\"" >> "$CACHE_FILE"
    fi

    # Native Bash JSON generation
    ssid_esc="${ssid//\"/\\\"}"
    sec_esc="${security//\"/\\\"}"
    icon_esc="${icon//\"/\\\"}"
    CONNECTED_JSON="{\"id\":\"$ssid_esc\",\"ssid\":\"$ssid_esc\",\"icon\":\"$icon_esc\",\"signal\":\"$signal\",\"security\":\"$sec_esc\",\"ip\":\"$IP\",\"freq\":\"$FREQ\",\"saved\":true}"
else
    CONNECTED_JSON="null"
fi

# Keep raw SSID for nmcli connect; trim only for dedupe + saved matching.
NETWORKS_JSON=$(nmcli -t -f active,ssid,signal,security device wifi list --rescan no | awk -F: -v sf="$SAVED_TMP" '
    BEGIN {
        while ((getline line < sf) > 0) saved[line] = 1
        close(sf)
    }
    $2 != "" && $1 != "yes" {
        raw=$2; signal=$3; security=$4;
        trim=raw
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", trim);
        if (trim == "" || seen[trim]++) next;
        is_saved = ((raw in saved) || (trim in saved)) ? "true" : "false";

        ssid=raw
        gsub(/"/, "\\\"", ssid);
        gsub(/"/, "\\\"", security);
        
        if (signal >= 80) icon="󰤨";
        else if (signal >= 60) icon="󰤥";
        else if (signal >= 40) icon="󰤢";
        else if (signal >= 20) icon="󰤟";
        else icon="󰤯";
        
        printf "{\"id\":\"%s\",\"ssid\":\"%s\",\"icon\":\"%s\",\"signal\":\"%s\",\"security\":\"%s\",\"saved\":%s}\n", ssid, ssid, icon, signal, security, is_saved
    }
' | head -n 24 | paste -sd, -)

rm -f "$SAVED_TMP"

if [ -z "$NETWORKS_JSON" ]; then
    NETWORKS_JSON="[]"
else
    NETWORKS_JSON="[$NETWORKS_JSON]"
fi

# Final JSON output
echo "{\"power\":\"on\",\"connected\":$CONNECTED_JSON,\"networks\":$NETWORKS_JSON}"
