#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# CONSTANTS & ARGUMENTS
# -----------------------------------------------------------------------------
QS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BT_PID_FILE="$HOME/.cache/bt_scan_pid"
BT_SCAN_LOG="$HOME/.cache/bt_scan.log"
SRC_DIR="${WALLPAPER_DIR:-${srcdir:-$HOME/Pictures/Wallpapers}}"
THUMB_DIR="$HOME/.cache/wallpaper_picker/thumbs"

# User-specific cache directory matching the QML logic
QS_NETWORK_CACHE="${XDG_RUNTIME_DIR:-$HOME/.cache}/qs_network"
mkdir -p "$QS_NETWORK_CACHE"

IPC_FILE="/tmp/qs_widget_state"
NETWORK_MODE_FILE="$QS_NETWORK_CACHE/mode"

# Notifications are handled by Quickshell DynamicIsland NotificationServer.
# Stop legacy daemons to avoid duplicate popups.
pkill -x dunst >/dev/null 2>&1 || true
pkill -x mako >/dev/null 2>&1 || true
pkill -x swaync >/dev/null 2>&1 || true

ACTION="$1"
TARGET="$2"
SUBTARGET="$3"

# -----------------------------------------------------------------------------
# FAST PATH: WORKSPACE SWITCHING
# -----------------------------------------------------------------------------
if [[ "$ACTION" =~ ^[0-9]+$ ]]; then
    WORKSPACE_NUM="$ACTION"
    echo "close" > "$IPC_FILE"
    
    CMD="workspace $WORKSPACE_NUM"
    [[ "$2" == "move" ]] && CMD="movetoworkspace $WORKSPACE_NUM"
    hyprctl --batch "dispatch $CMD" >/dev/null 2>&1
    exit 0
fi

# -----------------------------------------------------------------------------
# PREP FUNCTIONS
# -----------------------------------------------------------------------------
handle_wallpaper_prep() {
    mkdir -p "$THUMB_DIR"
    (
        for thumb in "$THUMB_DIR"/*; do
            [ -e "$thumb" ] || continue
            filename=$(basename "$thumb")
            clean_name="${filename#000_}"
            if [ ! -f "$SRC_DIR/$clean_name" ]; then rm -f "$thumb"; fi
        done

        for img in "$SRC_DIR"/*.{jpg,jpeg,png,webp,gif,mp4,mkv,mov,webm}; do
            [ -e "$img" ] || continue
            filename=$(basename "$img")
            extension="${filename##*.}"

            if [[ "${extension,,}" == "webp" ]]; then
                new_img="${img%.*}.jpg"
                magick "$img" "$new_img"
                rm -f "$img"
                img="$new_img"
                filename=$(basename "$img")
                extension="jpg"
            fi

            if [[ "${extension,,}" =~ ^(mp4|mkv|mov|webm)$ ]]; then
                thumb="$THUMB_DIR/000_$filename"
                [ -f "$THUMB_DIR/$filename" ] && rm -f "$THUMB_DIR/$filename"
                if [ ! -f "$thumb" ]; then
                     ffmpeg -y -ss 00:00:05 -i "$img" -vframes 1 -f image2 -q:v 2 "$thumb" > /dev/null 2>&1
                fi
            else
                thumb="$THUMB_DIR/$filename"
                if [ ! -f "$thumb" ]; then
                    magick "$img" -resize x420 -quality 70 "$thumb"
                fi
            fi
        done
    ) &

    TARGET_THUMB=""
    CURRENT_SRC=""

    if pgrep -a "mpvpaper" > /dev/null; then
        CURRENT_SRC=$(pgrep -a mpvpaper | grep -o "$SRC_DIR/[^' ]*" | head -n1)
        CURRENT_SRC=$(basename "$CURRENT_SRC")
    fi

    if [ -z "$CURRENT_SRC" ] && command -v swww >/dev/null; then
        CURRENT_SRC=$(swww query 2>/dev/null | grep -o "$SRC_DIR/[^ ]*" | head -n1)
        CURRENT_SRC=$(basename "$CURRENT_SRC")
    fi

    if [ -n "$CURRENT_SRC" ]; then
        EXT="${CURRENT_SRC##*.}"
        if [[ "${EXT,,}" =~ ^(mp4|mkv|mov|webm)$ ]]; then
            TARGET_THUMB="000_$CURRENT_SRC"
        else
            TARGET_THUMB="$CURRENT_SRC"
        fi
    fi
    
    export WALLPAPER_THUMB="$TARGET_THUMB"
}

handle_network_prep() {
    # BT scan is owned by NetworkPopup.qml (with auto-restart on bluez perturbations).
    # We only kick a wifi rescan here.
    (nmcli device wifi rescan) &
}

# -----------------------------------------------------------------------------
# ZOMBIE WATCHDOG
# -----------------------------------------------------------------------------
MAIN_QML_PATH="$HOME/.config/hypr/scripts/quickshell/Main.qml"
BAR_QML_PATH="$HOME/.config/hypr/scripts/quickshell/TopBar.qml"

# /proc comm is the real binary name ("quickshell"), then the cmdline is checked
# for the qml path. pgrep -f matches its own argv and any shell that happens to
# contain the pattern, which skipped starts or spawned duplicates.
qs_running() {
    local needle="$1"
    local comm_path pid comm
    for comm_path in /proc/[0-9]*/comm; do
        comm=$(cat "$comm_path" 2>/dev/null) || continue
        [ "$comm" = "quickshell" ] || continue
        pid=${comm_path#/proc/}
        pid=${pid%/comm}
        tr '\0' '\n' < "/proc/$pid/cmdline" 2>/dev/null | grep -F -q -- "$needle" && return 0
    done
    return 1
}

stop_quickshell_matching() {
    local needle="$1"
    local comm_path pid comm
    for comm_path in /proc/[0-9]*/comm; do
        comm=$(cat "$comm_path" 2>/dev/null) || continue
        [ "$comm" = "quickshell" ] || continue
        pid=${comm_path#/proc/}
        pid=${pid%/comm}
        if tr '\0' '\n' < "/proc/$pid/cmdline" 2>/dev/null | grep -F -q -- "$needle"; then
            kill "$pid" 2>/dev/null || true
        fi
    done
}

ensure_topbar() {
    if qs_running "TopBar.qml"; then
        return 0
    fi
    quickshell -p "$BAR_QML_PATH" >/dev/null 2>&1 &
    disown
}

ensure_main() {
    if ! qs_running "Main.qml"; then
        quickshell -p "$MAIN_QML_PATH" >/dev/null 2>&1 &
        disown
    fi
    # Wait until Main is up and its IPC watcher can see the toggle write.
    local i
    for i in $(seq 1 40); do
        qs_running "Main.qml" && break
        sleep 0.05
    done
    sleep 0.2
}

# Login / bare restart: only the bar stays up. Popups live in Main, which is
# started on demand below and idle-quits on its own. No island, launcher,
# clipboard, or speedtest process is kept resident.
if [ -z "${ACTION:-}" ]; then
    stop_quickshell_matching "Main.qml"
    stop_quickshell_matching "DynamicIsland.qml"
    stop_quickshell_matching "AppLauncher.qml"
    stop_quickshell_matching "ClipboardViewer.qml"
    stop_quickshell_matching "NotificationPopups.qml"
    stop_quickshell_matching "IslandNotifications.qml"
    pkill -f "speedtest_daemon.sh" >/dev/null 2>&1 || true
    pkill -f "^nmcli monitor$" >/dev/null 2>&1 || true
fi

ensure_topbar

# -----------------------------------------------------------------------------
# IPC ROUTING
# -----------------------------------------------------------------------------
if [[ "$ACTION" == "close" ]]; then
    echo "close" > "$IPC_FILE"
    if [[ "$TARGET" == "network" || "$TARGET" == "all" || -z "$TARGET" ]]; then
        if [ -f "$BT_PID_FILE" ]; then
            kill $(cat "$BT_PID_FILE") 2>/dev/null
            rm -f "$BT_PID_FILE"
        fi
        (bluetoothctl scan off > /dev/null 2>&1) &
    fi
    exit 0
fi

if [[ "$ACTION" == "open" || "$ACTION" == "toggle" ]]; then
    # External app launcher (wofi). Clipboard UI is removed from the idle rice.
    if [[ "$TARGET" == "launcher" ]]; then
        bash "$HOME/.config/hypr/scripts/rofi_show.sh" &
        disown
        exit 0
    fi
    if [[ "$TARGET" == "clipboard" ]]; then
        exit 0
    fi

    ensure_main
    # Give the IPC watcher a moment, then write (and keep a copy for late readers).
    sleep 0.15
    CURRENT_MODE=$(cat "$NETWORK_MODE_FILE" 2>/dev/null)

    # Network widget: bash must still own the mode-file logic here,
    # so we read qs_active_widget only for this specific case.
    if [[ "$TARGET" == "network" ]]; then
        ACTIVE_WIDGET=$(cat /tmp/qs_active_widget 2>/dev/null)
        if [[ "$ACTION" == "toggle" && "$ACTIVE_WIDGET" == "network" ]]; then
            if [[ -n "$SUBTARGET" ]]; then
                if [[ "$CURRENT_MODE" == "$SUBTARGET" ]]; then
                    echo "close" > "$IPC_FILE"
                else
                    echo "$SUBTARGET" > "$NETWORK_MODE_FILE"
                    echo "$TARGET" > "$IPC_FILE"
                fi
            else
                echo "close" > "$IPC_FILE"
            fi
        else
            handle_network_prep
            [[ -n "$SUBTARGET" ]] && echo "$SUBTARGET" > "$NETWORK_MODE_FILE"
            echo "$TARGET" > "$IPC_FILE"
        fi
        exit 0
    fi

    # All other widgets: just write the target.
    # QML reads its own in-memory currentActive to decide open vs close —
    # no stale qs_active_widget reads, no race condition.
    if [[ "$TARGET" == "wallpaper" ]]; then
        handle_wallpaper_prep
        echo "$TARGET:$WALLPAPER_THUMB" > "$IPC_FILE"
    else
        echo "$TARGET" > "$IPC_FILE"
    fi
    exit 0
fi
