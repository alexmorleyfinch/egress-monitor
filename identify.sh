#!/bin/bash

set -euo pipefail

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
    echo "{"type:"$name"
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


