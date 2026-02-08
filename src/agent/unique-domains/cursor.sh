#!/bin/bash

DNSMASQ_LOG="/var/log/dnsmasq-queries.log"

get_from_cursor() {
    local STATE_FILE=$1

    # Get cursor (line number we last processed)
    local CURSOR=$(cat "$STATE_FILE" 2>/dev/null || echo "0")
    
    # Get total lines in log file
    local TOTAL_LINES=$(wc -l < "$DNSMASQ_LOG" 2>/dev/null || echo "0")
    
    # If cursor > total (file was rotated), start from beginning
    if [ "$CURSOR" -gt "$TOTAL_LINES" ]; then
        CURSOR=0
    fi
    
    # Read new lines only
    if [ "$TOTAL_LINES" -gt "$CURSOR" ]; then
        tail -n +$((CURSOR + 1)) "$DNSMASQ_LOG" | \
            awk '
            # Process query lines
            /query\[/ && !/query\[PTR\]/ {
                # Extract timestamp
                timestamp = $1 " " $2 " " $3
                
                # Extract domain
                for(i=4; i<=NF; i++) {
                    if ($i ~ /query\[/) {
                        domain = $(i+1)
                        break
                    }
                }
                
                # Store query for matching with reply
                queries[domain] = timestamp
            }
            
            # Process reply lines with IP
            /reply/ && !/NXDOMAIN/ && !/NODATA/ {
                # Extract domain and IP
                for(i=4; i<=NF; i++) {
                    if ($i == "is") {
                        domain = $(i-1)
                        ip = $(i+1)
                        
                        # Validate IP format
                        if (ip ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) {
                            timestamp = queries[domain]
                            if (timestamp != "") {
                                print timestamp, domain, ip
                            }
                        }
                        break
                    }
                }
            }
            '
    fi
}

update_cursor() {
    local STATE_FILE=$1
    local TOTAL_LINES=$(wc -l < "$DNSMASQ_LOG" 2>/dev/null || echo "0")
    
    # Save current line count
    echo "$TOTAL_LINES" > "$STATE_FILE"
}
