#!/usr/bin/env bash
# Query LibrePods daemon for AirPods battery + noise mode.
# Emits compact JSON for TopBar / LibrePodsPopup. On failure → connected:false.

CTL="${LIBREPODS_CTL:-$HOME/librepods/linux/build/librepods-ctl}"
if [ ! -x "$CTL" ]; then
    CTL="$(command -v librepods-ctl 2>/dev/null || true)"
fi

fallback() {
    jq -n -c '{
        connected: false,
        active: false,
        noise: "off",
        name: "",
        address: "",
        left: 0, right: 0, case: 0,
        left_charging: false, right_charging: false, case_charging: false,
        left_available: false, right_available: false, case_available: false,
        percent: 0,
        icon: "󱡏",
        noise_icon: "󰓃",
        label: ""
    }'
}

if [ -z "$CTL" ] || [ ! -x "$CTL" ]; then
    fallback
    exit 0
fi

raw=$(timeout 0.8 "$CTL" status 2>/dev/null) || { fallback; exit 0; }
raw=$(echo "$raw" | tr -d '\r' | head -n1)
if [ -z "$raw" ] || ! echo "$raw" | jq -e . >/dev/null 2>&1; then
    fallback
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENSURE_A2DP="$SCRIPT_DIR/../librepods/ensure_a2dp.sh"
if [ -x "$ENSURE_A2DP" ] && echo "$raw" | jq -e '.connected == true' >/dev/null 2>&1; then
    MAC=$(echo "$raw" | jq -r '.address // empty')
    timeout 2 "$ENSURE_A2DP" "$MAC" >/dev/null 2>&1 || true
fi

echo "$raw" | jq -c '
  . as $d
  | ($d.connected == true) as $active
  | (
      [ (if ($d.left_available and ($d.left // 0) > 0) then $d.left else empty end),
        (if ($d.right_available and ($d.right // 0) > 0) then $d.right else empty end) ]
      | if length > 0 then min else 0 end
    ) as $pct
  | (
      if ($d.noise == "anc") then "󰋋"
      elif ($d.noise == "transparency") then "󰓃"
      elif ($d.noise == "adaptive") then "󰥰"
      else "󰟎"
      end
    ) as $nicon
  | (
      if $active then "󱡏" else "󰂲" end
    ) as $icon
  | {
      connected: ($d.connected == true),
      active: $active,
      noise: ($d.noise // "off"),
      name: ($d.name // ""),
      address: ($d.address // ""),
      left: ($d.left // 0),
      right: ($d.right // 0),
      case: ($d.case // 0),
      left_charging: ($d.left_charging == true),
      right_charging: ($d.right_charging == true),
      case_charging: ($d.case_charging == true),
      left_available: ($d.left_available == true),
      right_available: ($d.right_available == true),
      case_available: ($d.case_available == true),
      percent: $pct,
      icon: $icon,
      noise_icon: $nicon,
      label: (if $active then ("\($pct)%") else "" end)
    }
'
