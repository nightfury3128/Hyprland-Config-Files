#!/usr/bin/env bash
# Easy Effects has been removed. Keep EQ UI state without launching any DSP sink.

STATE_FILE="/tmp/eq_state.json"

if [ ! -f "$STATE_FILE" ]; then
    echo '{"b1": 0, "b2": 0, "b3": 0, "b4": 0, "b5": 0, "b6": 0, "b7": 0, "b8": 0, "b9": 0, "b10": 0, "preset": "Flat", "pending": false}' > "$STATE_FILE"
fi

save_preset() {
    jq -n -c --arg b1 "$1" --arg b2 "$2" --arg b3 "$3" --arg b4 "$4" --arg b5 "$5" \
          --arg b6 "$6" --arg b7 "$7" --arg b8 "$8" --arg b9 "$9" --arg b10 "${10}" --arg p "${11}" \
       '{"b1": $b1, "b2": $b2, "b3": $b3, "b4": $b4, "b5": $b5, "b6": $b6, "b7": $b7, "b8": $b8, "b9": $b9, "b10": $b10, "preset": $p, "pending": false}' > "$STATE_FILE"
}

cmd=$1
arg1=$2
arg2=$3

case $cmd in
    "get") cat "$STATE_FILE" ;;
    "set_band")
        tmp=$(cat "$STATE_FILE")
        updated=$(echo "$tmp" | jq -c --arg val "$arg2" ".b$arg1 = \$val | .preset = \"Custom\" | .pending = true")
        echo "$updated" > "$STATE_FILE"
        ;;
    "apply")
        tmp=$(cat "$STATE_FILE")
        updated=$(echo "$tmp" | jq -c ".pending = false")
        echo "$updated" > "$STATE_FILE"
        ;;
    "preset")
        case $arg1 in
            "Flat")    save_preset 0 0 0 0 0 0 0 0 0 0 "Flat" ;;
            "Bass")    save_preset 5 7 5 2 1 0 0 0 1 2 "Bass" ;;
            "Treble")  save_preset -2 -1 0 1 2 3 4 5 6 6 "Treble" ;;
            "Vocal")   save_preset -2 -1 1 3 5 5 4 2 1 0 "Vocal" ;;
            "Pop")     save_preset 2 4 2 0 1 2 4 2 1 2 "Pop" ;;
            "Rock")    save_preset 5 4 2 -1 -2 -1 2 4 5 6 "Rock" ;;
            "Jazz")    save_preset 3 3 1 1 1 1 2 1 2 3 "Jazz" ;;
            "Classic") save_preset 0 1 2 2 2 2 1 2 3 4 "Classic" ;;
        esac
        ;;
esac
