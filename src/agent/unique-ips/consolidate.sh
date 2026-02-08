#!/bin/bash

STATE_FILE=$1
OUTPUT_FILE=$2

if [[ -z "$STATE_FILE" || -z "$OUTPUT_FILE" ]]; then
    echo "Usage: $0 <state_file> <output_file>"
    exit 1
fi

get_from_cursor() {
    local STATE_FILE=$1

    # Get cursor
    local CURSOR=$(cat "$STATE_FILE" 2>/dev/null || echo "")
    local JOURNAL_ARGS="${CURSOR:+--after-cursor=$CURSOR}"

    journalctl -k $JOURNAL_ARGS -o short-iso --grep="EGRESS:" 2>/dev/null | \
        grep "OUT=eth0" | \
        grep -v "DST=127\." | \
        grep -oP '^[0-9T:.+-]+|DST=[0-9.]+' | \
        paste - - | \
        sed 's/DST=//'
}

update_cursor() {
    local STATE_FILE=$1

    # Save cursor
    journalctl -k -n 1 --grep="EGRESS:" -o export 2>/dev/null | grep -m1 "__CURSOR=" | cut -d= -f2- > "$STATE_FILE"
}

# 1. Load existing counts and timestamps
declare -A IP_COUNTS
declare -A IP_LAST_SEEN

if [[ -f "$OUTPUT_FILE" ]]; then
    while read ip count timestamp; do
        [[ -n "$ip" ]] && IP_COUNTS[$ip]=$count && IP_LAST_SEEN[$ip]=$timestamp
    done < "$OUTPUT_FILE"
fi

# Process new entries - capture timestamp and IP
while read timestamp ip; do
    # Skip empty or malformed lines
    [[ -z "$ip" || -z "$timestamp" ]] && continue
    # Validate IP looks like an IP
    [[ ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && continue

    IP_COUNTS[$ip]=$((${IP_COUNTS[$ip]:-0} + 1))
    IP_LAST_SEEN[$ip]=$timestamp
done < <(get_from_cursor "$STATE_FILE")

# Write out updated counts with last seen timestamp
for ip in "${!IP_COUNTS[@]}"; do
    echo "$ip ${IP_COUNTS[$ip]} ${IP_LAST_SEEN[$ip]}"
done | sort -t' ' -k2 -rn > "$OUTPUT_FILE"

# Save cursor
update_cursor "$STATE_FILE"
