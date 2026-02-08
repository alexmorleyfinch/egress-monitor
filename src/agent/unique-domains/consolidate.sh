#!/bin/bash

STATE_FILE=$1
OUTPUT_FILE=$2

if [[ -z "$STATE_FILE" || -z "$OUTPUT_FILE" ]]; then
    echo "Usage: $0 <state_file> <output_file>"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# load functions `get_from_cursor` and `update_cursor`
source "$SCRIPT_DIR/cursor.sh"

# 1. Load existing counts, timestamps, and IPs
declare -A DOMAIN_COUNTS
declare -A DOMAIN_LAST_SEEN
declare -A DOMAIN_IPS

if [[ -f "$OUTPUT_FILE" ]]; then
    while IFS=' ' read -r domain count timestamp ips; do
        if [[ -n "$domain" ]]; then
            DOMAIN_COUNTS[$domain]=$count
            DOMAIN_LAST_SEEN[$domain]=$timestamp
            DOMAIN_IPS[$domain]=$ips
        fi
    done < "$OUTPUT_FILE"
fi

# Process new entries - capture timestamp, domain, and IP
while read timestamp domain ip; do
    # Skip empty or malformed lines
    [[ -z "$domain" || -z "$timestamp" || -z "$ip" ]] && continue
    
    # Basic domain validation (has at least one dot, no spaces)
    [[ ! "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] && continue
    
    # Skip localhost and common internal names
    [[ "$domain" =~ ^localhost$ ]] && continue
    [[ "$domain" =~ \.local$ ]] && continue
    
    # Increment count
    DOMAIN_COUNTS[$domain]=$((${DOMAIN_COUNTS[$domain]:-0} + 1))
    DOMAIN_LAST_SEEN[$domain]=$timestamp
    
    # Add IP to comma-separated list if not already present
    if [[ -z "${DOMAIN_IPS[$domain]}" ]]; then
        DOMAIN_IPS[$domain]=$ip
    elif [[ ! ",${DOMAIN_IPS[$domain]}," =~ ,$ip, ]]; then
        DOMAIN_IPS[$domain]="${DOMAIN_IPS[$domain]},$ip"
    fi
done < <(get_from_cursor "$STATE_FILE")

# Write out updated counts with last seen timestamp and IPs
for domain in "${!DOMAIN_COUNTS[@]}"; do
    echo "$domain ${DOMAIN_COUNTS[$domain]} ${DOMAIN_LAST_SEEN[$domain]} ${DOMAIN_IPS[$domain]}"
done | sort -t' ' -k2 -rn > "$OUTPUT_FILE"

# Save cursor
update_cursor "$STATE_FILE"
