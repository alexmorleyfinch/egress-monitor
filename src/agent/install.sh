#!/bin/bash
# Idempotent script to install egress logging

set -e  # Exit on error

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)" 
   exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="/var/log/egress-monitor"

echo "Setting up egress monitoring..."

# ==================================== Bootstrap ====================================
mkdir -p "$ROOT_DIR"
chmod 755 "$ROOT_DIR"
chown root:root "$ROOT_DIR"


# =============================== Install "unique-ips" ===============================
source "$SCRIPT_DIR/unique-ips/setup.sh" # load function `install_unique_ips`
install_unique_ips \
    "$SCRIPT_DIR/unique-ips" \
    "$ROOT_DIR/unique-ips.cursor" \
    "$ROOT_DIR/unique-ips.log"


# ============================= Install "unique-domains" =============================
source "$SCRIPT_DIR/unique-domains/setup.sh" # load function `install_unique_domains`
install_unique_domains \
    "$SCRIPT_DIR/unique-domains" \
    "$ROOT_DIR/unique-domains.cursor" \
    "$ROOT_DIR/unique-domains.log"


# ===================================== Complete =====================================
echo "Install complete"
