#!/usr/bin/env bash

set -u

PROFILE_DIRS=(
    "$HOME/.config/BraveSoftware/Brave-Browser/Default"
    "$HOME/.config/google-chrome/Default"
    "$HOME/.config/chromium/Default"
)

DB_PATH=""
for p in "${PROFILE_DIRS[@]}"; do
    if [ -f "$p/History" ]; then
        DB_PATH="$p/History"
        break
    fi
done

if [ -z "$DB_PATH" ]; then
    echo '[]'
    exit 0
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
    echo '[]'
    exit 0
fi

TMP_DB="${XDG_RUNTIME_DIR:-/tmp}/qs_top_sites_history.db"
cp "$DB_PATH" "$TMP_DB" 2>/dev/null || {
    echo '[]'
    exit 0
}

SQL="
SELECT
  COALESCE(title, '') AS title,
  url AS url,
  visit_count AS visit_count
FROM urls
WHERE url LIKE 'http%'
  AND url NOT LIKE 'http://localhost%'
  AND url NOT LIKE 'https://localhost%'
  AND url NOT LIKE 'http://127.%'
  AND url NOT LIKE 'https://127.%'
  AND url NOT LIKE 'http://10.%'
  AND url NOT LIKE 'https://10.%'
  AND url NOT LIKE 'http://192.168.%'
  AND url NOT LIKE 'https://192.168.%'
  AND url NOT LIKE 'http://172.16.%'
  AND url NOT LIKE 'https://172.16.%'
  AND url NOT LIKE 'http://172.17.%'
  AND url NOT LIKE 'https://172.17.%'
  AND url NOT LIKE 'http://172.18.%'
  AND url NOT LIKE 'https://172.18.%'
  AND url NOT LIKE 'http://172.19.%'
  AND url NOT LIKE 'https://172.19.%'
  AND url NOT LIKE 'http://172.2%'
  AND url NOT LIKE 'https://172.2%'
  AND url NOT LIKE 'http://172.30.%'
  AND url NOT LIKE 'https://172.30.%'
  AND url NOT LIKE 'http://172.31.%'
  AND url NOT LIKE 'https://172.31.%'
  AND url NOT LIKE '%://%.local%'
  AND hidden = 0
ORDER BY visit_count DESC
LIMIT 12;
"

rows="$(sqlite3 -separator $'\t' "$TMP_DB" "$SQL" 2>/dev/null)"
rm -f "$TMP_DB"

if [ -z "$rows" ]; then
    echo '[]'
    exit 0
fi

echo "$rows" | awk -F '\t' '
BEGIN { print "["; first=1; count=0; }
{
    title=$1; url=$2; visits=$3;
    if (url == "") next;
    gsub(/"/, "\\\"", title);
    gsub(/"/, "\\\"", url);
    host=url;
    sub(/^https?:\/\//, "", host);
    sub(/^www\./, "", host);
    sub(/\/.*/, "", host);
    # Extra guard for any non-SQL-filtered local/dev hosts.
    if (host ~ /(^localhost$)|(^127\.)|(^10\.)|(^192\.168\.)|(^172\.(1[6-9]|2[0-9]|3[0-1])\.)|(\.local$)/) next;
    if (!first) printf(",\n");
    printf("  {\"title\":\"%s\",\"url\":\"%s\",\"host\":\"%s\",\"visits\":%s}", title, url, host, visits);
    first=0;
    count++;
    if (count >= 6) { nextfile; }
}
END { print "\n]"; }
'
