#!/bin/bash

PROJECT_ROOT="/data/bimmercodes/bits-downloader"
LOG_DIR="/data/bimmercodes/bits-downloader/logs"
mkdir -p "$LOG_DIR"

# Check if already running
if pgrep -f "torrent_manager.sh" > /dev/null; then
    echo "Torrent manager is already running!"
    echo "Use ./bin/bits-downloader.sh to access the monitor"
    exit 1
fi

# Make scripts executable
chmod +x "$PROJECT_ROOT/lib/torrent_manager.sh"
chmod +x "$PROJECT_ROOT/bin/monitor_torrents.sh"
chmod +x "$PROJECT_ROOT/bin/stop_torrents.sh"

echo "Starting torrent manager in background..."

# Start with nohup
nohup "$PROJECT_ROOT/lib/torrent_manager.sh" > "$LOG_DIR/nohup.log" 2>&1 &

echo "Torrent manager started with PID: $!"
echo ""
echo "Use ./bin/bits-downloader.sh to monitor and control torrents"
