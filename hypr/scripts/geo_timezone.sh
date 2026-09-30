#!/usr/bin/env bash
# geo_timezone.sh — IP geolocation daemon that keeps the *system* timezone in
# sync with the laptop's physical location. The system timezone (as reported by
# timedatectl) is the single source of truth; this script only decides *when*
# it should change.
#
# Flags:
#   --timezone   Print the current SYSTEM timezone (never a geolocation guess).
#   --sync       Force one geolocation + sync attempt, then exit.
#   --daemon     Run the periodic + NetworkManager-driven sync loop.

set -u

CACHE_DIR="${HOME}/.cache/quickshell/geo"
LOCATION_FILE="${CACHE_DIR}/location.json"
CANDIDATE_FILE="${CACHE_DIR}/.candidate_timezone"
SYNCED_TZ_FILE="${CACHE_DIR}/.synced_timezone"
LAST_FETCH_FILE="${CACHE_DIR}/.last_fetch"
LOCK_FILE="${CACHE_DIR}/geo_timezone.lock"
LOG_FILE="${CACHE_DIR}/geo_timezone.log"

AUTO_LOCATION="${GEO_TZ_AUTO_LOCATION:-1}"
SYNC_SYSTEM_TZ="${GEO_TZ_SYNC_SYSTEM:-1}"
LOCATION_TTL="${GEO_TZ_LOCATION_TTL:-1800}"
DAEMON_INTERVAL="${GEO_TZ_INTERVAL:-1800}"
# Minimum seconds between geolocation fetches (debounces nmcli storms).
FETCH_MIN_INTERVAL="${GEO_TZ_FETCH_MIN_INTERVAL:-120}"

resolved_tz=""
resolved_city=""
resolved_country=""

log() {
    mkdir -p "$CACHE_DIR"
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
}

system_tz() {
    if command -v timedatectl >/dev/null 2>&1; then
        timedatectl show -p Timezone --value 2>/dev/null || echo "UTC"
    else
        echo "UTC"
    fi
}

timezones_equivalent() {
    local a="$1" b="$2"
    [ "$a" = "$b" ] && return 0
    { [ "$a" = "Asia/Kolkata" ] && [ "$b" = "Asia/Calcutta" ]; } && return 0
    { [ "$a" = "Asia/Calcutta" ] && [ "$b" = "Asia/Kolkata" ]; } && return 0
    return 1
}

# Validate that a fetched JSON blob looks like real geolocation data:
# - parses as JSON
# - has a plausible Olson timezone id (Region/City form)
# - has a country field
tz_is_olson() {
    local tz="$1"
    [ -n "$tz" ] && [ "$tz" != "null" ] && [[ "$tz" == */* ]] && [ -f "/usr/share/zoneinfo/$tz" ]
}

validate_and_extract() {
    # $1 = path to candidate JSON. Populates resolved_tz/city/country on success.
    local file="$1"
    command -v jq >/dev/null 2>&1 || return 1
    jq -e . "$file" >/dev/null 2>&1 || return 1

    local tz city country
    tz=$(jq -r '
        if (.timezone | type) == "string" then .timezone
        elif (.timezone | type) == "object" then (.timezone.id // empty)
        else empty end
    ' "$file" 2>/dev/null)
    city=$(jq -r '.city // empty' "$file" 2>/dev/null)
    country=$(jq -r '.country // .country_name // empty' "$file" 2>/dev/null)

    tz_is_olson "$tz" || return 1
    [ -n "$country" ] || return 1

    resolved_tz="$tz"
    resolved_city="$city"
    resolved_country="$country"
    return 0
}

fetch_location() {
    # Rate-limit fetches so nmcli storms don't hammer providers.
    local now last
    now=$(date +%s)
    last=$(cat "$LAST_FETCH_FILE" 2>/dev/null || echo 0)
    if [ $((now - last)) -lt "$FETCH_MIN_INTERVAL" ]; then
        return 2
    fi
    echo "$now" > "$LAST_FETCH_FILE"

    # Query multiple HTTPS providers and require *agreement* on the timezone.
    # A single provider (e.g. ipapi.co maps some Cincinnati Bell IPv6 blocks
    # to Avondale, AZ) can be systematically wrong for a given ISP; a
    # majority/agreement rule filters that class of error.
    # ip-api.com HTTPS requires a paid key, so it's intentionally not used.
    local providers=(
        "https://ipwho.is/"
        "https://ipapi.co/json/"
        "https://ifconfig.co/json"
    )

    local staging="${CACHE_DIR}/.fetch"
    rm -rf "$staging"
    mkdir -p "$staging"

    local i=0 url out
    for url in "${providers[@]}"; do
        out="$staging/p${i}.json"
        curl -sf --max-time 6 -H 'User-Agent: geo_timezone.sh' "$url" > "$out" 2>/dev/null || true
        if [ ! -s "$out" ] || ! validate_and_extract "$out"; then
            rm -f "$out"
        fi
        i=$((i+1))
    done

    # Tally TZ votes across successful, validated responses.
    local tz_counts
    tz_counts=$(for f in "$staging"/p*.json; do
        [ -f "$f" ] || continue
        jq -r '
            if (.timezone | type) == "string" then .timezone
            elif (.timezone | type) == "object" then (.timezone.id // empty)
            else empty end
        ' "$f" 2>/dev/null
    done | sort | uniq -c | sort -rn)

    if [ -z "$tz_counts" ]; then
        rm -rf "$staging"
        return 1
    fi

    local top_count top_tz
    top_count=$(echo "$tz_counts" | awk 'NR==1 {print $1}')
    top_tz=$(echo   "$tz_counts" | awk 'NR==1 {print $2}')

    if [ "$top_count" -lt 2 ]; then
        log "no provider agreement (results: $(echo "$tz_counts" | tr '\n' ';'))"
        rm -rf "$staging"
        return 1
    fi

    # Pick the provider file that reported the winning TZ.
    local winner=""
    local f
    for f in "$staging"/p*.json; do
        [ -f "$f" ] || continue
        local ftz
        ftz=$(jq -r '
            if (.timezone | type) == "string" then .timezone
            elif (.timezone | type) == "object" then (.timezone.id // empty)
            else empty end
        ' "$f" 2>/dev/null)
        if [ "$ftz" = "$top_tz" ]; then
            winner="$f"
            break
        fi
    done

    if [ -n "$winner" ] && validate_and_extract "$winner"; then
        mv "$winner" "$LOCATION_FILE"
        rm -rf "$staging"
        return 0
    fi

    rm -rf "$staging"
    return 1
}

parse_cached_location() {
    resolved_tz=""
    resolved_city=""
    resolved_country=""
    [ -f "$LOCATION_FILE" ] || return 1
    validate_and_extract "$LOCATION_FILE"
}

# Decide whether we should apply resolved_tz to the system.
# Guard: require two consecutive fetches to agree on the same TZ before
# switching, so a single flaky provider result cannot flip the system TZ.
should_apply_tz() {
    local candidate="$1"
    local current_sys
    current_sys=$(system_tz)

    # Already correct → nothing to do.
    if timezones_equivalent "$current_sys" "$candidate"; then
        rm -f "$CANDIDATE_FILE"
        return 1
    fi

    local prev
    prev=$(cat "$CANDIDATE_FILE" 2>/dev/null || true)
    if [ "$prev" = "$candidate" ]; then
        # Confirmed on second consecutive fetch — safe to apply.
        rm -f "$CANDIDATE_FILE"
        return 0
    fi

    echo "$candidate" > "$CANDIDATE_FILE"
    log "candidate tz $candidate (current=$current_sys) — waiting for confirmation"
    return 1
}

sync_system_timezone() {
    if [[ "$SYNC_SYSTEM_TZ" == "0" ]]; then
        return 1
    fi
    if ! tz_is_olson "$resolved_tz"; then
        return 1
    fi
    command -v timedatectl >/dev/null 2>&1 || return 1

    should_apply_tz "$resolved_tz" || return 0

    if timedatectl set-timezone "$resolved_tz" 2>>"$LOG_FILE"; then
        echo "$resolved_tz" > "$SYNCED_TZ_FILE"
        log "timezone set to ${resolved_tz}${resolved_city:+ ($resolved_city, $resolved_country)}"
        return 0
    fi

    log "failed to set timezone to ${resolved_tz}"
    return 1
}

resolve_location() {
    resolved_tz=""
    resolved_city=""
    resolved_country=""

    if [[ "$AUTO_LOCATION" == "0" ]]; then
        return 1
    fi

    mkdir -p "$CACHE_DIR"

    local force="${1:-0}"
    local fetch_needed=1
    local now mtime
    now=$(date +%s)

    if [ "$force" != "1" ] && [ -f "$LOCATION_FILE" ]; then
        mtime=$(stat -c %Y "$LOCATION_FILE" 2>/dev/null || echo 0)
        if [ $((now - mtime)) -lt "$LOCATION_TTL" ]; then
            fetch_needed=0
        fi
    fi

    if [ "$fetch_needed" -eq 1 ] && command -v curl >/dev/null 2>&1; then
        if ! fetch_location; then
            log "location fetch failed or rate-limited"
        fi
    fi

    parse_cached_location
}

run_sync() {
    local force="${1:-0}"
    resolve_location "$force" || return 1
    sync_system_timezone
}

# --timezone always returns the *system* timezone. Geolocation is only used
# to decide when to change it; the UI must never disagree with the OS.
print_timezone() {
    system_tz
}

cleanup_daemon() {
    # Kill any lingering background children of this daemon.
    local children
    children=$(jobs -p 2>/dev/null || true)
    if [ -n "$children" ]; then
        kill $children 2>/dev/null || true
    fi
    pkill -P $$ 2>/dev/null || true
}

daemon_main() {
    mkdir -p "$CACHE_DIR"
    exec 9>"$LOCK_FILE"
    if ! flock -n 9; then
        exit 0
    fi

    trap cleanup_daemon EXIT INT TERM

    log "daemon started (pid=$$)"
    run_sync 1 || true

    # Periodic re-check.
    (
        while true; do
            sleep "$DAEMON_INTERVAL"
            run_sync 0 || true
        done
    ) &
    local periodic_pid=$!

    # NetworkManager change → force a re-check (debounced by FETCH_MIN_INTERVAL).
    # Filter to real connectivity transitions so Wi-Fi scans / signal blips
    # don't wake this process on every event.
    if command -v nmcli >/dev/null 2>&1; then
        (
            nmcli monitor 2>/dev/null | while IFS= read -r line; do
                case "$line" in
                    *"Connectivity is now 'full'"*|\
                    *"NetworkManager is now in the 'connected' state"*)
                        sleep 5
                        run_sync 1 || true
                        ;;
                esac
            done
        ) &
        local nm_pid=$!
        wait "$periodic_pid" "$nm_pid"
    else
        wait "$periodic_pid"
    fi
}

case "${1:-}" in
    --timezone)
        print_timezone
        ;;
    --sync)
        run_sync 1
        ;;
    --daemon|"")
        daemon_main
        ;;
    *)
        echo "Usage: $0 [--timezone|--sync|--daemon]" >&2
        exit 1
        ;;
esac
