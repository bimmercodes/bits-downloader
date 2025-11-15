#!/bin/bash

echo "Stopping torrent manager..."

# Kill torrent manager script
if pgrep -f "torrent_manager.sh" > /dev/null; then
    pkill -f "torrent_manager.sh"
    echo "Torrent manager stopped"
else
    echo "Torrent manager was not running"
fi

# Stop transmission-daemon
if transmission-remote -l &>/dev/null; then
    echo "Stopping transmission-daemon..."
    transmission-daemon --stop
    sleep 2
    echo "Transmission-daemon stopped"
else
    echo "Transmission-daemon was not running"
fi

# Remove PID file
rm -f /tmp/torrent_manager.pid

echo "All torrent services stopped"
