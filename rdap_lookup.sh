#!/bin/bash
IP="$1"
TIMEOUT=30

output=$(curl -sL --max-time $TIMEOUT -w "\n%{http_code}" "https://rdap.org/ip/$IP" 2>&1)
exit_code=$?

if [ $exit_code -eq 28 ]; then
    echo "{\"type\": \"RDAP\", \"status\": \"timeout\", \"value\": \"\"}"
elif [ $exit_code -ne 0 ]; then
    echo "{\"type\": \"RDAP\", \"status\": \"error\", \"value\": \"\"}"
else
    http_code=$(echo "$output" | tail -n1)
    body=$(echo "$output" | sed '$d')

    if [ "$http_code" -ge 400 ]; then
        echo "{\"type\": \"RDAP\", \"status\": \"error\", \"value\": \"\", \"http_code\": $http_code}"
    else
	result=$(echo "$body" | jq -r '
	    {
	        name: (
	            .name // 
	            first(.entities[] | select(.roles[] | IN("registrant", "administrative")) | .vcardArray[1][] | select(.[0]=="fn") | .[3]) //
	            first(.entities[0].vcardArray[1][] | select(.[0]=="fn") | .[3]) //
	            (if .handle | test("^[0-9]") then null else .handle end) //
	            null
	        ),
	        country: (.country // null),
	        email: (
	            first(.entities[0].vcardArray[1][] | select(.[0]=="email") | .[3]) //
	            null
	        ),
	        address: (
	            first(.entities[0].vcardArray[1][] | select(.[0]=="adr") | .[1].label) //
	            first(.entities[0].vcardArray[1][] | select(.[0]=="adr") | .[3] | map(select(. != "")) | join(", ")) //
	            null
	        )
	    }
	' 2>/dev/null)
        name=$(echo "$result" | jq -r '.name // empty')

        if [ -z "$name" ]; then
            echo "{\"type\": \"RDAP\", \"status\": \"not_found\", \"value\": \"\"}"
        else
            echo "$result" | jq -c '{type: "RDAP", status: "ok"} + .'
        fi
    fi
fi

