#!/bin/bash
IP="$1"

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
        echo "{\"type\": \"PTR\", \"status\": \"nxdomain\", \"value\": \"\", \"resolver\": \"$resolver_name\"}"
        exit 0
    else
        echo "{\"type\": \"PTR\", \"status\": \"ok\", \"value\": \"$output\", \"resolver\": \"$resolver_name\"}"
        exit 0
    fi
done

echo "{\"type\": \"PTR\", \"status\": \"error\", \"value\": \"\", \"resolver\": \"none\"}"

