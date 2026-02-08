#!/bin/bash

set -euo pipefail

INPUT_FILE="/var/log/egress/unique-ips.log"
OUTPUT_FOLDER="/var/log/egress/identities"
RATE_LIMIT_SECONDS=0.5

mkdir -p "$OUTPUT_FOLDER"

get_reverse_dns() {
  local ip="$1"
  local result
  result=$(dig +short +time=2 +tries=1 -x "$ip" 2>/dev/null | head -1 | sed 's/\.$//')
  if [[ -n "$result" && ! "$result" =~ ^";;" ]]; then
    echo "$result"
  else
    return 1
  fi
}

get_rdap_name() {
  local ip="$1"
  local result
  result=$(curl -sL --max-time 10 "https://rdap.org/ip/$ip" | jq -r '.name // empty' 2>/dev/null)
  if [[ -n "$result" ]]; then
    echo "$result"
  else
    return 1
  fi
}

get_best_name() {
  local ip="$1"
  local name

  # Try reverse DNS first — more specific (actual hostnames)
  if name=$(get_reverse_dns "$ip"); then
    echo "$name"
    return 0
  fi

  # Fall back to RDAP — org/network level
  if name=$(get_rdap_name "$ip"); then
    echo "$name"
    return 0
  fi

  echo "UNKNOWN"
}

update_identity_file() {
  local ip="$1"
  local name="$2"
  local timestamp
  timestamp=$(date -Iseconds)
  local file="$OUTPUT_FOLDER/$ip"

  if [[ -f "$file" ]]; then
    # Check if this name already exists
    if grep -q "^${name} " "$file" 2>/dev/null; then
      # Update timestamp for existing name
      sed -i "s|^${name} .*|${name} ${timestamp}|" "$file"
    else
      # New name, append
      echo "${name} ${timestamp}" >> "$file"
    fi
  else
    # New file
    echo "${name} ${timestamp}" > "$file"
  fi
}

echo "Starting IP identification"

# Read IPs into array to avoid subshell issue
mapfile -t lines < "$INPUT_FILE"

total=${#lines[@]}
count=0

echo "Found $total IPs in $INPUT_FILE"

for line in "${lines[@]}"; do
  count=$((count + 1))

  # Parse: "ip count datetime"
  ip=$(echo "$line" | awk '{print $1}')

  if [[ -z "$ip" ]]; then
    continue
  fi

  echo "[$count/$total] Processing $ip..."

  name=$(get_best_name "$ip")
  update_identity_file "$ip" "$name"

  echo "  -> $name"

  sleep "$RATE_LIMIT_SECONDS"
done

echo "Done. Results in $OUTPUT_FOLDER"

