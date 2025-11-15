#!/bin/bash

LOG_DIR="/data/torrents/torrent_logs"
mkdir -p "$LOG_DIR"

# Check if already running
if pgrep -f "torrent_manager.sh" > /dev/null; then
    echo "Torrent manager is already running!"
    echo "Use ./monitor_torrents.sh to view progress"
    exit 1
fi

# Make scripts executable
chmod +x torrent_manager.sh
chmod +x monitor_torrents.sh
chmod +x stop_torrents.sh

echo "Starting torrent manager in background..."

# Start with nohup
nohup ./torrent_manager.sh > "$LOG_DIR/nohup.log" 2>&1 &

echo "Torrent manager started with PID: $!"
echo ""
echo "Commands:"
echo "  Monitor progress:  ./monitor_torrents.sh"
echo "  View logs:         tail -f /data/torrents/torrent_logs/torrent_manager.log"
echo "  Stop all:          ./stop_torrents.sh"
echo "  Add torrent:       transmission-remote -a <magnet_link_or_file>"
echo "  List torrents:     transmission-remote -l"
echo ""
echo "Add torrents to /data/torrents/torrent_list.txt (one per line) or"
echo "place .torrent files in /data/torrents/torrents/ directory"
