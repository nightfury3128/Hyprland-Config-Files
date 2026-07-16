#!/usr/bin/env bash
# geo_timezone.sh — IP geolocation + system timezone sync (independent of weather.sh)

set -u

CACHE_DIR="${HOME}/.cache/quickshell/geo"
LOCATION_FILE="${CACHE_DIR}/location.json"
SYNCED_TZ_FILE="${CACHE_DIR}/.synced_timezone"
LOCK_FILE="${CACHE_DIR}/geo_timezone.lock"
LOG_FILE="${CACHE_DIR}/geo_timezone.log"

AUTO_LOCATION="${GEO_TZ_AUTO_LOCATION:-1}"
SYNC_SYSTEM_TZ="${GEO_TZ_SYNC_SYSTEM:-1}"
LOCATION_TTL="${GEO_TZ_LOCATION_TTL:-1800}"
DAEMON_INTERVAL="${GEO_TZ_INTERVAL:-1800}"

resolved_tz=""
resolved_city=""

log() {
    mkdir -p "$CACHE_DIR"
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
}

timezones_equivalent() {
    local a="$1" b="$2"
    [ "$a" = "$b" ] && return 0
    { [ "$a" = "Asia/Kolkata" ] && [ "$b" = "Asia/Calcutta" ]; } && return 0
    { [ "$a" = "Asia/Calcutta" ] && [ "$b" = "Asia/Kolkata" ]; } && return 0
    return 1
}

fetch_location() {
    local tmp="${LOCATION_FILE}.tmp"
    rm -f "$tmp"

    curl -sf --max-time 6 "https://ipapi.co/json/" > "$tmp" 2>/dev/null || true
    if [ ! -s "$tmp" ]; then
        curl -sf --max-time 6 "https://ipwho.is/" > "$tmp" 2>/dev/null || true
    fi
    if [ ! -s "$tmp" ]; then
        curl -sf --max-time 6 "http://ip-api.com/json/" > "$tmp" 2>/dev/null || true
    fi

    if [ -s "$tmp" ]; then
        mv "$tmp" "$LOCATION_FILE"
        return 0
    fi

    rm -f "$tmp"
    return 1
}

parse_location() {
    resolved_tz=""
    resolved_city=""

    [ -f "$LOCATION_FILE" ] || return 1
    command -v jq >/dev/null 2>&1 || return 1

    resolved_tz=$(jq -r '
        if (.timezone | type) == "string" then .timezone
        elif (.timezone | type) == "object" then (.timezone.id // empty)
        else empty end
    ' "$LOCATION_FILE" 2>/dev/null)

    resolved_city=$(jq -r '.city // empty' "$LOCATION_FILE" 2>/dev/null)
    [ -n "$resolved_tz" ] && [ "$resolved_tz" != "null" ]
}

resolve_location() {
    resolved_tz=""
    resolved_city=""

    if [[ "$AUTO_LOCATION" == "0" ]]; then
        return 1
    fi

    mkdir -p "$CACHE_DIR"

    local force="${1:-0}"
    local fetch_needed=1
    local now mtime

    now=$(date +%s)
    if [ "$force" = "1" ]; then
        fetch_needed=1
    elif [ -f "$LOCATION_FILE" ]; then
        mtime=$(stat -c %Y "$LOCATION_FILE" 2>/dev/null || echo 0)
        if [ $((now - mtime)) -lt "$LOCATION_TTL" ]; then
            fetch_needed=0
        fi
    fi

    if [ "$fetch_needed" -eq 1 ] && command -v curl >/dev/null 2>&1; then
        if ! fetch_location; then
            log "location fetch failed"
        fi
    fi

    parse_location
}

sync_system_timezone() {
    if [[ "$SYNC_SYSTEM_TZ" == "0" ]]; then
        return 1
    fi
    if [ -z "$resolved_tz" ] || [[ "$resolved_tz" != */* ]]; then
        return 1
    fi
    if ! command -v timedatectl >/dev/null 2>&1; then
        return 1
    fi

    if [ -f "$SYNCED_TZ_FILE" ] && [ "$(cat "$SYNCED_TZ_FILE" 2>/dev/null)" = "$resolved_tz" ]; then
        return 0
    fi

    local current_tz
    current_tz=$(timedatectl show -p Timezone --value 2>/dev/null || true)
    if [ -n "$current_tz" ] && timezones_equivalent "$current_tz" "$resolved_tz"; then
        echo "$resolved_tz" > "$SYNCED_TZ_FILE"
        return 0
    fi

    if timedatectl set-timezone "$resolved_tz" 2>/dev/null; then
        echo "$resolved_tz" > "$SYNCED_TZ_FILE"
        log "timezone set to ${resolved_tz}${resolved_city:+ ($resolved_city)}"
        return 0
    fi

    log "failed to set timezone to ${resolved_tz}"
    return 1
}

print_timezone() {
    if resolve_location && [ -n "$resolved_tz" ]; then
        printf '%s\n' "$resolved_tz"
        return 0
    fi

    if command -v timedatectl >/dev/null 2>&1; then
        timedatectl show -p Timezone --value 2>/dev/null || echo "UTC"
    else
        echo "UTC"
    fi
}

run_sync() {
    local force="${1:-0}"
    if ! resolve_location "$force"; then
        return 1
    fi
    sync_system_timezone
}

daemon_main() {
    mkdir -p "$CACHE_DIR"
    exec 9>"$LOCK_FILE"
    if ! flock -n 9; then
        exit 0
    fi

    log "daemon started"
    run_sync 1 || true

    (
        while true; do
            sleep "$DAEMON_INTERVAL"
            run_sync 0 || true
        done
    ) &

    if command -v nmcli >/dev/null 2>&1; then
        nmcli monitor 2>/dev/null | while IFS= read -r _line; do
            sleep 3
            run_sync 1 || true
        done
    else
        wait
    fi
}

case "${1:-}" in
    --timezone)
        print_timezone
        ;;
    --sync)
        run_sync 1
        ;;
    --daemon)
        daemon_main
        ;;
    "")
        daemon_main
        ;;
    *)
        echo "Usage: $0 [--timezone|--sync|--daemon]" >&2
        exit 1
        ;;
esac
