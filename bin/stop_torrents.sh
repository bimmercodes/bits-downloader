#!/bin/bash

# Stop Torrents - Stop the torrent manager service
# Refactored with SOLID and DRY principles

# Get script directory and project root
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$BIN_DIR/.." && pwd)"

# Source libraries
source "$PROJECT_ROOT/lib/config.sh"
source "$PROJECT_ROOT/lib/utils.sh"
source "$PROJECT_ROOT/lib/transmission_api.sh"

print_info "Stopping torrent manager..."

# Kill torrent manager script
if pgrep -f "torrent_manager.sh" > /dev/null; then
    pkill -f "torrent_manager.sh"
    print_success "Torrent manager stopped"
else
    print_warning "Torrent manager was not running"
fi

# Stop transmission-daemon
if is_transmission_running; then
    print_info "Stopping transmission-daemon..."
    stop_transmission
    print_success "Transmission-daemon stopped"
else
    print_warning "Transmission-daemon was not running"
fi

# Remove PID file
rm -f /tmp/torrent_manager.pid

echo ""
print_success "All torrent services stopped"
