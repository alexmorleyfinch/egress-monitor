#!/bin/bash

ptr_lookup() {
    local IP="$1"

    resolvers=("" "1.1.1.1" "8.8.8.8" "9.9.9.9")
    resolver_names=("system" "cloudflare" "google" "quad9")

    for i in "${!resolvers[@]}"; do
        resolver="${resolvers[$i]}"
        resolver_name="${resolver_names[$i]}"
        
        if [ -z "$resolver" ]; then
            output=$(dig +short +time=1 +tries=1 -x "$IP" 2>&1)
        else
            output=$(dig +short +time=1 +tries=1 -x "$IP" @"$resolver" 2>&1)
        fi
        exit_code=$?
        
        if echo "$output" | grep -q "timed out\|no servers could be reached"; then
            continue
        elif [ $exit_code -ne 0 ]; then
            continue
        elif [ -z "$output" ]; then
            echo "[no_ptr]"
            exit 0
        else
            echo $output
            exit 0
        fi
    done

    echo "[no_ip]"
}

rdap_lookup() {
    local IP="$1"
    local TIMEOUT=30

    output=$(curl -sL --max-time $TIMEOUT -w "\n%{http_code}" "https://rdap.org/ip/$IP" 2>&1)
    exit_code=$?

    if [ $exit_code -eq 28 ]; then
        echo "[timeout]"
    elif [ $exit_code -ne 0 ]; then
        echo "[exit_$exit_code]"
    else
        http_code=$(echo "$output" | tail -n1)
        body=$(echo "$output" | sed '$d')

        if [ "$http_code" -ge 400 ]; then
            echo "[http_$http_code]"
        else
            result=$(echo "$body" | jq -r '
                # Recursively find the first entity handle (depth-first)
                def firstHandle:
                if type != "array" then null
                else
                    reduce .[] as $ent (null;
                    if . != null then .
                    elif $ent.handle then $ent.handle
                    elif $ent.entities then ($ent.entities | firstHandle)
                    else null
                    end
                    )
                end;

                # Nullify name if it looks like a bare IP or IP range
                (.name // "" |
                if test("^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$") then null
                elif test("^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3} - [0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$") then null
                elif . == "" then null
                else .
                end
                ) // ((.entities // []) | firstHandle) // .port43
            ' 2>/dev/null)

            echo "$result"
        fi
    fi
}

# Fetch logs from remote server
ip_log=$(ssh "$1" cat /var/log/egress-monitor/unique-ips.log)
domain_log=$(ssh "$1" cat /var/log/egress-monitor/unique-domains.log)

# Create temporary files for processing
tmp_ip=$(mktemp)
tmp_domain=$(mktemp)
tmp_mapping=$(mktemp)

echo "$ip_log" > "$tmp_ip"
echo "$domain_log" > "$tmp_domain"

# Build a mapping file of IP -> Domain
while IFS= read -r line; do
    domain=$(echo "$line" | awk '{print $1}')
    ips=$(echo "$line" | awk '{print $4}')
    
    # Split IPs if multiple
    IFS=',' read -ra ip_array <<< "$ips"
    
    for ip in "${ip_array[@]}"; do
        echo "$ip|$domain" >> "$tmp_mapping"
    done
done < "$tmp_domain"

# Print header
printf "%-20s %-6s %-25s %-40s %-30s %-30s\n" "IP_ADDRESS" "COUNT" "TIMESTAMP" "DOMAIN" "PTR" "RDAP"
printf "%s\n" "$(printf '%.0s-' {1..155})"

# Process all IPs from ip_log
while IFS= read -r line; do
    ip=$(echo "$line" | awk '{print $1}')
    count=$(echo "$line" | awk '{print $2}')
    timestamp=$(echo "$line" | awk '{print $3}')

    # Get domain(s) for this IP
    domain=$(grep "^${ip}|" "$tmp_mapping" | cut -d'|' -f2 | tr '\n' ', ' | sed 's/,$//')

    ptr=$(ptr_lookup "$ip")
    rdap=$(rdap_lookup "$ip")

    sleep 1s

    printf "%-20s %-6s %-25s %-40s %-30s %-30s\n" "$ip" "$count" "$timestamp" "$domain" "$ptr" "$rdap"
done < "$tmp_ip"

# Cleanup
rm -f "$tmp_ip" "$tmp_domain" "$tmp_mapping"
