#!/bin/bash
# Send a file to a specific LocalSend device
# Usage: localsend_send.sh <file> <target-ip>

FILE="$1"
TARGET="$2"

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    notify-send "LocalSend" "File not found" -i dialog-error; exit 1
fi
if [ -z "$TARGET" ]; then
    notify-send "LocalSend" "No target device specified" -i dialog-error; exit 1
fi

PORT=53317
FILENAME=$(basename "$FILE")
FILESIZE=$(stat -c%s "$FILE")
FILETYPE=$(file -b --mime-type "$FILE")
FILE_ID="qs_$(date +%s%N | md5sum | head -c8)"

FINGERPRINT_FILE="$HOME/.cache/qs_localsend_fp"
[ -f "$FINGERPRINT_FILE" ] || openssl rand -hex 16 > "$FINGERPRINT_FILE"
FINGERPRINT=$(cat "$FINGERPRINT_FILE")

BODY=$(python3 - <<EOF
import json
print(json.dumps({
    "info": {
        "alias": "QuickShell Stash",
        "version": "2.1",
        "deviceModel": None,
        "deviceType": "headless",
        "fingerprint": "$FINGERPRINT",
        "port": $PORT,
        "protocol": "https",
        "download": False
    },
    "files": {
        "$FILE_ID": {
            "id": "$FILE_ID",
            "fileName": "$FILENAME",
            "size": $FILESIZE,
            "fileType": "$FILETYPE",
            "sha256": None,
            "preview": None,
            "metadata": None
        }
    }
}))
EOF
)

RESP=$(curl -sk --max-time 30 \
    -X POST "https://$TARGET:$PORT/api/localsend/v2/prepare-upload" \
    -H "Content-Type: application/json" \
    -d "$BODY")

SESSION=$(python3 -c "import sys,json; print(json.loads(sys.argv[1]).get('sessionId',''))" "$RESP" 2>/dev/null)
TOKEN=$(python3 -c "import sys,json; d=json.loads(sys.argv[1]); print(d.get('files',{}).get('$FILE_ID',''))" "$RESP" 2>/dev/null)

if [ -z "$SESSION" ] || [ -z "$TOKEN" ]; then
    notify-send "LocalSend" "Rejected or timed out" -i dialog-error; exit 1
fi

curl -sk --max-time 120 \
    -X POST "https://$TARGET:$PORT/api/localsend/v2/upload?sessionId=$SESSION&fileId=$FILE_ID&token=$TOKEN" \
    -H "Content-Type: $FILETYPE" \
    --data-binary @"$FILE" >/dev/null \
    && notify-send "LocalSend" "Sent: $FILENAME" -i emblem-ok-symbolic \
    || notify-send "LocalSend" "Upload failed" -i dialog-error