#! /bin/bash

CONSOLIDATE_SCRIPT_PATH="/usr/local/bin/egress-monitor-consolidate-ips.sh"

install_unique_ips() {
    local COMPONENT_DIR=$1
    local CURSOR_FILE=$2
    local OUTPUT_FILE=$3

    echo "Installing unique-ips monitor..."

    # Create files if they don't exist
    touch "$CURSOR_FILE" "$OUTPUT_FILE"
    chown root:root "$CURSOR_FILE" "$OUTPUT_FILE"
    chmod 644 "$CURSOR_FILE" "$OUTPUT_FILE"

    # Install any binaries
    cp -f "$COMPONENT_DIR/consolidate.sh" "$CONSOLIDATE_SCRIPT_PATH"
    chmod +x "$CONSOLIDATE_SCRIPT_PATH"

    # Start logging egress to journalctl (idempotent - delete first if exists)
    if ! iptables -C OUTPUT -m state --state NEW -j LOG --log-prefix "EGRESS: " --log-level 4 2>/dev/null; then
        iptables -A OUTPUT -m state --state NEW -j LOG --log-prefix "EGRESS: " --log-level 4
    fi

    # Add cron job
    {
        echo "*/5 * * * * root $CONSOLIDATE_SCRIPT_PATH '$CURSOR_FILE' '$OUTPUT_FILE'"
        echo ""  # Trailing newline
    } > /etc/cron.d/egress-unique-ips
    chmod 644 /etc/cron.d/egress-unique-ips

    echo "✓ unique-ips installed"
}

uninstall_unique_ips() {
    local CURSOR_FILE=$1
    local OUTPUT_FILE=$2
    echo "Uninstalling unique-ips monitor..."

    # Remove cron
    rm -f /etc/cron.d/egress-unique-ips

    # Remove script
    rm -f "$CONSOLIDATE_SCRIPT_PATH"

    # Remove the iptables rule
    iptables -D OUTPUT -m state --state NEW -j LOG --log-prefix "EGRESS: " --log-level 4 2>/dev/null || true

    rm -f "$CURSOR_FILE"
    rm -f "$OUTPUT_FILE"

    echo "✓ unique-ips uninstalled"
}
