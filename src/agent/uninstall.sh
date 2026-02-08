#!/bin/bash
# Idempotent script to uninstall egress logging

set -e  # Exit on error

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)" 
   exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="/var/log/egress-monitor"

echo "Uninstalling egress monitoring..."

# ============================ Uninstall "unique-domains" ============================
source "$SCRIPT_DIR/unique-domains/setup.sh" # load function `uninstall_unique_domains`
uninstall_unique_domains \
    "$ROOT_DIR/unique-domains.cursor" \
    "$ROOT_DIR/unique-domains.log"


# ============================== Uninstall "unique-ips" ==============================
source "$SCRIPT_DIR/unique-ips/setup.sh" # load function `uninstall_unique_ips`
uninstall_unique_ips \
    "$ROOT_DIR/unique-ips.cursor" \
    "$ROOT_DIR/unique-ips.log"


# =================================== Remove data ===================================
# Give user a choice
read -p "Remove all log data? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$ROOT_DIR"
    echo "Data removed"
else
    echo "Keeping data in $ROOT_DIR"
fi


# ===================================== Complete =====================================
echo "Uninstall complete"
