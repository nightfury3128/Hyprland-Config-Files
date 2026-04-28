#!/usr/bin/env bash

set -u

emit_fail() {
    local reason="$1"
    printf '{"ok":false,"reason":"%s","download":0,"upload":0,"ping":0,"ts":%s}\n' "$reason" "$(date +%s)"
}

emit_success_ookla() {
    local raw="$1"
    printf '%s' "$raw" | jq -c '
        {
          ok: true,
          reason: "",
          download: (((.download.bandwidth // 0) * 8) / 1000000),
          upload: (((.upload.bandwidth // 0) * 8) / 1000000),
          ping: (.ping.latency // 0),
          ts: (now | floor)
        }'
}

emit_success_cli() {
    local raw="$1"
    printf '%s' "$raw" | jq -c '
        {
          ok: true,
          reason: "",
          download: ((.download // 0) / 1000000),
          upload: ((.upload // 0) / 1000000),
          ping: (.ping // 0),
          ts: (now | floor)
        }'
}

if ! command -v jq >/dev/null 2>&1; then
    emit_fail "jq missing"
    exit 0
fi

TMP_ERR="$(mktemp)"
cleanup() { rm -f "$TMP_ERR"; }
trap cleanup EXIT

if command -v speedtest >/dev/null 2>&1; then
    raw="$(speedtest --accept-license --accept-gdpr --format=json 2>"$TMP_ERR" || true)"
    if [ -n "$raw" ] && printf '%s' "$raw" | jq -e '.download.bandwidth and .upload.bandwidth and .ping.latency' >/dev/null 2>&1; then
        emit_success_ookla "$raw"
        exit 0
    fi
fi

if command -v speedtest-cli >/dev/null 2>&1; then
    raw="$(speedtest-cli --json 2>"$TMP_ERR" || true)"
    if [ -n "$raw" ] && printf '%s' "$raw" | jq -e '.download and .upload and .ping' >/dev/null 2>&1; then
        emit_success_cli "$raw"
        exit 0
    fi

    # Retry using secure transport for environments where plain retrieval fails.
    raw="$(speedtest-cli --secure --json 2>"$TMP_ERR" || true)"
    if [ -n "$raw" ] && printf '%s' "$raw" | jq -e '.download and .upload and .ping' >/dev/null 2>&1; then
        emit_success_cli "$raw"
        exit 0
    fi

    # Last-chance fallback: parse simple output mode.
    simple="$(speedtest-cli --secure --simple 2>"$TMP_ERR" || true)"
    if [ -n "$simple" ]; then
        d="$(printf '%s' "$simple" | awk -F': ' '/Download/ {print $2}' | awk '{print $1}' | head -n1)"
        u="$(printf '%s' "$simple" | awk -F': ' '/Upload/ {print $2}' | awk '{print $1}' | head -n1)"
        p="$(printf '%s' "$simple" | awk -F': ' '/Ping/ {print $2}' | awk '{print $1}' | head -n1)"
        if [ -n "$d" ] && [ -n "$u" ] && [ -n "$p" ]; then
            printf '{"ok":true,"reason":"","download":%s,"upload":%s,"ping":%s,"ts":%s}\n' "$d" "$u" "$p" "$(date +%s)"
            exit 0
        fi
    fi
fi

if command -v speedtest >/dev/null 2>&1 || command -v speedtest-cli >/dev/null 2>&1; then
    reason="$(tr '\n' ' ' < "$TMP_ERR" | sed 's/[[:space:]]\+/ /g;s/^ //;s/ $//')"
    [ -z "$reason" ] && reason="speedtest failed"
    emit_fail "$reason"
else
    emit_fail "speedtest missing"
fi
