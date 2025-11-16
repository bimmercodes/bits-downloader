#!/bin/bash

# Start Torrents - Launch the torrent manager service
# Refactored with SOLID and DRY principles

# Get script directory and project root
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$BIN_DIR/.." && pwd)"

# Source libraries
source "$PROJECT_ROOT/lib/config.sh"
source "$PROJECT_ROOT/lib/utils.sh"
source "$PROJECT_ROOT/lib/transmission_api.sh"

# Ensure directories exist
ensure_directories

# Ensure dependency exists before attempting to start
if ! ensure_transmission_available; then
    print_error "transmission-daemon is required. Install transmission-cli and transmission-daemon first."
    exit 1
fi

# Check if already running
if pgrep -f "torrent_manager.sh" > /dev/null; then
    print_warning "Torrent manager is already running!"
    echo "Use ./bin/bits-manager.sh to access the monitor"
    exit 1
fi

# Make scripts executable
chmod +x "$PROJECT_ROOT/lib"/*.sh "$PROJECT_ROOT/bin"/*.sh "$PROJECT_ROOT/ui"/*.sh 2>/dev/null

print_info "Starting torrent manager in background..."

# Start with nohup
nohup "$PROJECT_ROOT/lib/torrent_manager.sh" > "$LOG_DIR/nohup.log" 2>&1 &
PID=$!

sleep 1

# Verify it started
if ps -p $PID > /dev/null 2>&1; then
    print_success "Torrent manager started with PID: $PID"
else
    print_error "Failed to start torrent manager"
    echo "Check logs at: $LOG_DIR/nohup.log"
    exit 1
fi

echo ""
echo "Download directory: $DOWNLOAD_DIR"
echo "Logs directory: $LOG_DIR"
echo ""
echo "Use ./bin/bits-manager.sh to monitor and control torrents"
