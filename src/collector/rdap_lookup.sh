#!/bin/bash
IP="$1"
TIMEOUT=30

output=$(curl -sL --max-time $TIMEOUT -w "\n%{http_code}" "https://rdap.org/ip/$IP" 2>&1)
exit_code=$?

if [ $exit_code -eq 28 ]; then
    exit 2 # timeout
elif [ $exit_code -ne 0 ]; then
    exit 1 # error
else
    http_code=$(echo "$output" | tail -n1)
    body=$(echo "$output" | sed '$d')

    if [ "$http_code" -ge 400 ]; then
        exit $http_code
    else
		echo "$body"
    fi
fi

