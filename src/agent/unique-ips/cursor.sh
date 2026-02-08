#!/bin/bash

get_from_cursor() {
    local STATE_FILE=$1

    # Get cursor
    local CURSOR=$(cat "$STATE_FILE" 2>/dev/null || echo "")
    local JOURNAL_ARGS="${CURSOR:+--after-cursor=$CURSOR}"

    journalctl -k $JOURNAL_ARGS -o short-iso --grep="EGRESS:" 2>/dev/null | \
        grep "OUT=eth0" | \
        grep -v "DST=127\." | \
        grep -oP '^[0-9T:.+-]+|DST=[0-9.]+' | \
        paste - - | \
        sed 's/DST=//'
}

update_cursor() {
    local STATE_FILE=$1

    # Save cursor
    journalctl -k -n 1 --grep="EGRESS:" -o export 2>/dev/null | grep -m1 "__CURSOR=" | cut -d= -f2- > "$STATE_FILE"
}