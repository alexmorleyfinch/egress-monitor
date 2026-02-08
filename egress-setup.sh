#!/bin/bash
# Idempotent script to setup egress logging

# Start logging egress to journalctl
sudo iptables -A OUTPUT -m state --state NEW -j LOG --log-prefix "EGRESS: " --log-level 4

# Create log dir for other scripts
mkdir -p /var/log/egress

echo "Setup complete"

