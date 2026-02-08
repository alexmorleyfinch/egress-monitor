#!/bin/bash

CONSOLIDATE_SCRIPT_PATH="/usr/local/bin/egress-monitor-consolidate-domains.sh"
DNSMASQ_CONF="/etc/dnsmasq.d/99-egress-logging.conf"
DNSMASQ_LOG="/var/log/dnsmasq-queries.log"

install_unique_domains() {
    local COMPONENT_DIR=$1
    local CURSOR_FILE=$2
    local OUTPUT_FILE=$3

    echo "Installing unique-domains monitor..."

    # Create files if they don't exist
    touch "$CURSOR_FILE" "$OUTPUT_FILE"
    chown root:root "$CURSOR_FILE" "$OUTPUT_FILE"
    chmod 644 "$CURSOR_FILE" "$OUTPUT_FILE"

    # Install dnsmasq if not present
    if ! command -v dnsmasq &> /dev/null; then
        echo "Installing dnsmasq..."
        apt-get update -qq
        apt-get install -y dnsmasq
    fi

    # Configure dnsmasq for query logging
    cat > "$DNSMASQ_CONF" << EOF
# Egress monitoring - log all DNS queries
log-queries
log-facility=$DNSMASQ_LOG
EOF

    # Create log file
    touch "$DNSMASQ_LOG"
    chown root:root "$DNSMASQ_LOG"
    chmod 644 "$DNSMASQ_LOG"

    # Install consolidation script
    cp -f "$COMPONENT_DIR/consolidate.sh" "$CONSOLIDATE_SCRIPT_PATH"
    chmod +x "$CONSOLIDATE_SCRIPT_PATH"

    # Setup log rotation
    cat > /etc/logrotate.d/dnsmasq-queries << EOF
$DNSMASQ_LOG {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    prerotate
        # Run consolidation before rotating to capture all entries
        $CONSOLIDATE_SCRIPT_PATH '$CURSOR_FILE' '$OUTPUT_FILE' 2>/dev/null || true
    endscript
    postrotate
        systemctl reload dnsmasq > /dev/null 2>&1 || true
    endscript
}
EOF

    # Restart dnsmasq to apply config
    systemctl restart dnsmasq
    systemctl enable dnsmasq

    # Add cron job
    {
        echo "*/5 * * * * root $CONSOLIDATE_SCRIPT_PATH '$CURSOR_FILE' '$OUTPUT_FILE'"
        echo ""
    } > /etc/cron.d/egress-unique-domains
    chmod 644 /etc/cron.d/egress-unique-domains

    echo "✓ unique-domains installed"
}

uninstall_unique_domains() {
    local CURSOR_FILE=$1
    local OUTPUT_FILE=$2
    
    echo "Uninstalling unique-domains monitor..."

    # Remove cron
    rm -f /etc/cron.d/egress-unique-domains

    # Remove script
    rm -f "$CONSOLIDATE_SCRIPT_PATH"

    # Remove dnsmasq config
    rm -f "$DNSMASQ_CONF"

    # Remove logrotate config
    rm -f /etc/logrotate.d/dnsmasq-queries

    # Restart dnsmasq (or stop if no other configs)
    if systemctl is-active dnsmasq &> /dev/null; then
        if [ -z "$(ls -A /etc/dnsmasq.d/ 2>/dev/null)" ]; then
            # No other configs, stop dnsmasq
            systemctl stop dnsmasq
            systemctl disable dnsmasq
            echo "Note: dnsmasq stopped (no other configs found)"
        else
            systemctl restart dnsmasq
        fi
    fi

    # Remove log file
    rm -f "$DNSMASQ_LOG"

    # Remove data files
    rm -f "$CURSOR_FILE"
    rm -f "$OUTPUT_FILE"

    echo "✓ unique-domains uninstalled"
    echo "Note: dnsmasq package not removed (run 'apt remove dnsmasq' if desired)"
}
