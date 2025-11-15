#!/bin/bash

# Configuration
TORRENT_DIR="/data/torrents/torrents"
DOWNLOAD_DIR="/data/torrents/downloads"
LOG_DIR="/data/torrents/torrent_logs"
TORRENT_LIST="/data/torrents/torrent_list.txt"
MAIN_LOG="$LOG_DIR/torrent_manager.log"
PID_FILE="/tmp/torrent_manager.pid"

# Create directories
mkdir -p "$TORRENT_DIR" "$DOWNLOAD_DIR" "$LOG_DIR"

# Logging function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$MAIN_LOG"
}

# Check if already running
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        log_message "ERROR: Torrent manager already running with PID $OLD_PID"
        exit 1
    else
        rm -f "$PID_FILE"
    fi
fi

# Save PID
echo $$ > "$PID_FILE"

# Trap to cleanup on exit
trap 'rm -f "$PID_FILE"; log_message "Torrent manager stopped"' EXIT

log_message "Starting torrent manager..."

# Stop any existing transmission-daemon
log_message "Stopping any existing transmission-daemon..."
pkill -9 -f transmission-daemon 2>/dev/null
sleep 3

# Start transmission-daemon with configuration
log_message "Starting transmission-daemon..."
transmission-daemon \
    --download-dir "$DOWNLOAD_DIR" \
    --incomplete-dir "$DOWNLOAD_DIR/.incomplete" \
    --logfile "$LOG_DIR/transmission.log" \
    --log-level=info \
    --encryption-preferred \
    --peerlimit-global 200 \
    --peerlimit-torrent 50 \
    --no-auth \
    --allowed "127.0.0.1" \
    --port 9091

# Wait for daemon to start with retry logic
log_message "Waiting for transmission-daemon to be ready..."
MAX_RETRIES=10
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    sleep 2
    if transmission-remote -l &>/dev/null; then
        log_message "Transmission-daemon started successfully on attempt $((RETRY_COUNT + 1))"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    log_message "Attempt $RETRY_COUNT/$MAX_RETRIES - daemon not ready yet..."
done

# Final check
if ! transmission-remote -l &>/dev/null; then
    log_message "ERROR: Failed to start transmission-daemon after $MAX_RETRIES attempts"
    log_message "Check $LOG_DIR/transmission.log for details"
    exit 1
fi

# Add torrents from list or directory
if [ -f "$TORRENT_LIST" ]; then
    log_message "Adding torrents from list..."
    while IFS= read -r torrent; do
        [ -z "$torrent" ] || [[ "$torrent" =~ ^# ]] && continue
        
        if [[ "$torrent" =~ ^magnet: ]] || [[ "$torrent" =~ ^http ]]; then
            transmission-remote -a "$torrent" &>/dev/null
            if [ $? -eq 0 ]; then
                log_message "Added: $torrent"
            else
                log_message "Failed to add: $torrent"
            fi
        elif [ -f "$torrent" ]; then
            transmission-remote -a "$torrent" &>/dev/null
            if [ $? -eq 0 ]; then
                log_message "Added file: $torrent"
            else
                log_message "Failed to add file: $torrent"
            fi
        fi
    done < "$TORRENT_LIST"
fi

# Add any .torrent files from torrent directory
for torrent_file in "$TORRENT_DIR"/*.torrent; do
    [ -f "$torrent_file" ] || continue
    transmission-remote -a "$torrent_file" &>/dev/null
    if [ $? -eq 0 ]; then
        log_message "Added torrent file: $(basename "$torrent_file")"
        mv "$torrent_file" "$TORRENT_DIR/added/"
    fi
done

# Start all torrents
transmission-remote -t all -s
log_message "Started all torrents"

# Monitor loop
while true; do
    # Get status
    STATUS=$(transmission-remote -l 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log_message "WARNING: Cannot connect to transmission-daemon"
        sleep 30
        continue
    fi
    
    # Parse active downloads
    ACTIVE=$(echo "$STATUS" | grep -E "Downloading|Seeding" | wc -l)
    TOTAL=$(echo "$STATUS" | tail -n 1 | awk '{print $1}')
    
    # Log summary every 5 minutes
    log_message "Status: Active: $ACTIVE | Total in queue: $TOTAL"
    
    # Detailed status to separate file
    echo "$STATUS" > "$LOG_DIR/current_status.txt"
    
    # Check completed
    while IFS= read -r line; do
        if echo "$line" | grep -q "100%.*Seeding"; then
            ID=$(echo "$line" | awk '{print $1}' | tr -d '*')
            NAME=$(transmission-remote -t "$ID" -i | grep "Name:" | cut -d: -f2- | xargs)
            if [ -n "$NAME" ]; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] COMPLETED: $NAME" >> "$LOG_DIR/completed.log"
                transmission-remote -t "$ID" --remove-and-delete &>/dev/null
            fi
        fi
    done <<< "$STATUS"
    
    sleep 300  # Check every 5 minutes
done
