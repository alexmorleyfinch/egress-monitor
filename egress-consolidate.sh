#!/bin/bash

STATE_FILE="/var/log/egress/tracker.state"
OUTPUT_FILE="/var/log/egress/unique-ips.log"

touch "$STATE_FILE"
touch "$OUTPUT_FILE"

# Load existing counts and timestamps
declare -A IP_COUNTS
declare -A IP_LAST_SEEN
while read ip count timestamp; do
    [[ -n "$ip" ]] && IP_COUNTS[$ip]=$count && IP_LAST_SEEN[$ip]=$timestamp
done < "$OUTPUT_FILE"

# Get cursor
CURSOR=$(cat "$STATE_FILE" 2>/dev/null || echo "")
JOURNAL_ARGS="${CURSOR:+--after-cursor=$CURSOR}"

# Process new entries - capture timestamp and IP
while read timestamp ip; do
    # Skip empty or malformed lines
    [[ -z "$ip" || -z "$timestamp" ]] && continue
    # Validate IP looks like an IP
    [[ ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && continue
    
    IP_COUNTS[$ip]=$((${IP_COUNTS[$ip]:-0} + 1))
    IP_LAST_SEEN[$ip]=$timestamp
done < <(journalctl -k $JOURNAL_ARGS -o short-iso --grep="EGRESS:" 2>/dev/null | \
    grep "OUT=eth0" | \
    grep -v "DST=127\." | \
    grep -oP '^[0-9T:.+-]+|DST=[0-9.]+' | \
    paste - - | \
    sed 's/DST=//')

# Write out updated counts with last seen timestamp
for ip in "${!IP_COUNTS[@]}"; do
    echo "$ip ${IP_COUNTS[$ip]} ${IP_LAST_SEEN[$ip]}"
done | sort -t' ' -k2 -rn > "$OUTPUT_FILE"

# Save cursor
journalctl -k -n 1 --grep="EGRESS:" -o export 2>/dev/null | grep -m1 "__CURSOR=" | cut -d= -f2- > "$STATE_FILE"

