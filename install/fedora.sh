#!/bin/bash

# BITS Downloader - Fedora/RHEL Installation Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==================================="
echo "BITS Downloader - Fedora/RHEL Install"
echo "==================================="
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root (use sudo)"
    exit 1
fi

# Install dependencies
echo "[1/3] Installing dependencies..."
dnf install -y \
    transmission-daemon \
    transmission-cli \
    dialog \
    curl \
    wget

# Stop transmission if running
echo "[2/3] Configuring transmission..."
systemctl stop transmission-daemon 2>/dev/null || true
systemctl disable transmission-daemon 2>/dev/null || true

# Install BITS Downloader
echo "[3/3] Installing BITS Downloader..."
cd "$PROJECT_ROOT"

# Make scripts executable
chmod +x bin/*.sh
chmod +x ui/*.sh
chmod +x install.sh
chmod +x uninstall.sh

# Create symlink
if [ ! -L /usr/local/bin/bits-downloader ]; then
    ln -sf "$PROJECT_ROOT/bin/bits-downloader.sh" /usr/local/bin/bits-downloader
fi

echo
echo "✓ Installation complete!"
echo
echo "Usage:"
echo "  bits-downloader         - Start BITS Downloader"
echo "  bits-downloader --help  - Show help"
echo
