#!/bin/bash

INPUT_FILE="/var/log/egress/unique-ips.log"
IDENTITIES_FOLDER="/var/log/egress/identities"

printf "%-15s %7s  %-25s  %s\n" "IP" "COUNT" "LAST_SEEN" "IDENTITIES"
printf "%-15s %7s  %-25s  %s\n" "---------------" "-------" "-------------------------" "----------"

while read -r ip count timestamp; do
  [[ -z "$ip" ]] && continue

  identity_file="$IDENTITIES_FOLDER/$ip"

  if [[ -f "$identity_file" ]]; then
    # First line: print with IP info
    first=true
    while read -r name resolved_at; do
      if $first; then
        printf "%-15s %7s  %-25s  %s (%s)\n" "$ip" "$count" "$timestamp" "$name" "$resolved_at"
        first=false
      else
        printf "%-15s %7s  %-25s  %s (%s)\n" "" "" "" "$name" "$resolved_at"
      fi
    done < "$identity_file"
  else
    printf "%-15s %7s  %-25s  %s\n" "$ip" "$count" "$timestamp" "-"
  fi
done < "$INPUT_FILE"

