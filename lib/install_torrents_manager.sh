#!/bin/bash

# Torrent Manager Installer - All-in-one script
# Run this on your target Ubuntu VM

set -e

echo "Installing Torrent Manager System..."

# Install transmission if needed
if ! command -v transmission-daemon &> /dev/null; then
    echo "Installing transmission packages..."
    sudo apt-get update
    sudo apt-get install -y transmission-cli transmission-daemon transmission-common
fi

# Create directory structure
mkdir -p /data/torrents/torrents/added
mkdir -p /data/torrents/downloads/.incomplete
mkdir -p /data/torrents/torrent_logs

# Create torrent_manager.sh
cat > /data/torrents/torrent_manager.sh << 'TORRENT_MANAGER_EOF'
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
transmission-daemon --stop 2>/dev/null
sleep 2

# Start transmission-daemon with configuration
transmission-daemon \
    --download-dir "$DOWNLOAD_DIR" \
    --incomplete-dir "$DOWNLOAD_DIR/.incomplete" \
    --logfile "$LOG_DIR/transmission.log" \
    --log-level=2 \
    --encryption-preferred \
    --peer-limit-global=200 \
    --peer-limit-per-torrent=50 \
    --download-queue-size=10 \
    --seed-queue-size=10 \
    --no-auth \
    --allowed "127.0.0.1" \
    --port 9091

sleep 3

# Check if daemon started
if ! transmission-remote -l &>/dev/null; then
    log_message "ERROR: Failed to start transmission-daemon"
    exit 1
fi

log_message "Transmission-daemon started successfully"

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
TORRENT_MANAGER_EOF

# Create monitor_torrents.sh
cat > /data/torrents/monitor_torrents.sh << 'MONITOR_EOF'
#!/bin/bash

LOG_DIR="/data/torrents/torrent_logs"
DOWNLOAD_DIR="/data/torrents/downloads"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}         TORRENT DOWNLOAD MONITOR${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

# Check if transmission-daemon is running
if ! transmission-remote -l &>/dev/null; then
    echo -e "${RED}ERROR: Transmission-daemon is not running!${NC}"
    echo "Start it with: ./start_torrents.sh"
    exit 1
fi

while true; do
    clear
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}         TORRENT DOWNLOAD MONITOR - $(date '+%H:%M:%S')${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"
    
    # Get detailed status
    STATUS=$(transmission-remote -l 2>/dev/null)
    
    # Overall stats
    STATS=$(transmission-remote -st 2>/dev/null)
    DOWNLOAD_SPEED=$(echo "$STATS" | grep "Download Speed:" | awk '{print $3, $4}')
    UPLOAD_SPEED=$(echo "$STATS" | grep "Upload Speed:" | awk '{print $3, $4}')
    
    echo -e "${YELLOW}SPEEDS:${NC} ↓ $DOWNLOAD_SPEED  ↑ $UPLOAD_SPEED\n"
    
    # Active torrents
    echo -e "${GREEN}ACTIVE DOWNLOADS:${NC}"
    echo "─────────────────────────────────────────────────────────────────"
    
    while IFS= read -r line; do
        if echo "$line" | grep -qE "Downloading|Up & Down"; then
            ID=$(echo "$line" | awk '{print $1}' | tr -d '*')
            PERCENT=$(echo "$line" | awk '{print $2}')
            ETA=$(echo "$line" | awk '{print $4}')
            SPEED=$(echo "$line" | awk '{print $5}')
            
            # Get name
            NAME=$(transmission-remote -t "$ID" -i 2>/dev/null | grep "Name:" | cut -d: -f2- | xargs)
            
            # Truncate name if too long
            if [ ${#NAME} -gt 40 ]; then
                NAME="${NAME:0:37}..."
            fi
            
            printf "%-40s %6s  ETA: %-8s Speed: %s\n" "$NAME" "$PERCENT" "$ETA" "$SPEED"
        fi
    done <<< "$STATUS"
    
    # Queued torrents
    echo -e "\n${YELLOW}QUEUED:${NC}"
    echo "─────────────────────────────────────────────────────────────────"
    
    QUEUED_COUNT=0
    while IFS= read -r line; do
        if echo "$line" | grep -q "Stopped"; then
            ID=$(echo "$line" | awk '{print $1}' | tr -d '*')
            NAME=$(transmission-remote -t "$ID" -i 2>/dev/null | grep "Name:" | cut -d: -f2- | xargs)
            
            if [ ${#NAME} -gt 50 ]; then
                NAME="${NAME:0:47}..."
            fi
            
            echo "$NAME"
            ((QUEUED_COUNT++))
        fi
    done <<< "$STATUS"
    
    [ $QUEUED_COUNT -eq 0 ] && echo "None"
    
    # Completed (from log)
    echo -e "\n${GREEN}RECENTLY COMPLETED:${NC}"
    echo "─────────────────────────────────────────────────────────────────"
    
    if [ -f "$LOG_DIR/completed.log" ]; then
        tail -n 5 "$LOG_DIR/completed.log" 2>/dev/null | while IFS= read -r line; do
            echo "$line"
        done
    else
        echo "None"
    fi
    
    # Disk usage
    echo -e "\n${BLUE}DISK USAGE:${NC}"
    df -h "$DOWNLOAD_DIR" | tail -n 1 | awk '{printf "Used: %s/%s (%s) - Available: %s\n", $3, $2, $5, $4}'
    
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo "Press Ctrl+C to exit | Refreshing every 5 seconds..."
    
    sleep 5
done
MONITOR_EOF

# Create start_torrents.sh
cat > /data/torrents/start_torrents.sh << 'START_EOF'
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
START_EOF

# Create stop_torrents.sh
cat > /data/torrents/stop_torrents.sh << 'STOP_EOF'
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
STOP_EOF

# Create torrent_control.sh
cat > /data/torrents/torrent_control.sh << 'CONTROL_EOF'
#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_menu() {
    echo -e "${GREEN}═══════════════════════════════════════════${NC}"
    echo -e "${GREEN}     TORRENT CONTROL PANEL${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════${NC}"
    echo "1) Add torrent (magnet/URL/file)"
    echo "2) Pause torrent"
    echo "3) Resume torrent"
    echo "4) Remove torrent"
    echo "5) Pause all"
    echo "6) Resume all"
    echo "7) Set download speed limit"
    echo "8) Set upload speed limit"
    echo "9) Show detailed info"
    echo "0) Exit"
    echo -e "${GREEN}═══════════════════════════════════════════${NC}"
}

# Check if transmission is running
if ! transmission-remote -l &>/dev/null; then
    echo -e "${RED}ERROR: Transmission-daemon is not running!${NC}"
    echo "Start it with: ./start_torrents.sh"
    exit 1
fi

while true; do
    show_menu
    read -p "Select option: " choice
    
    case $choice in
        1)
            read -p "Enter magnet link, URL, or file path: " torrent
            transmission-remote -a "$torrent"
            [ $? -eq 0 ] && echo -e "${GREEN}Torrent added successfully${NC}" || echo -e "${RED}Failed to add torrent${NC}"
            ;;
        2)
            transmission-remote -l
            read -p "Enter torrent ID to pause: " id
            transmission-remote -t "$id" -S
            ;;
        3)
            transmission-remote -l
            read -p "Enter torrent ID to resume: " id
            transmission-remote -t "$id" -s
            ;;
        4)
            transmission-remote -l
            read -p "Enter torrent ID to remove: " id
            read -p "Delete files too? (y/n): " delete
            if [ "$delete" = "y" ]; then
                transmission-remote -t "$id" --remove-and-delete
            else
                transmission-remote -t "$id" -r
            fi
            ;;
        5)
            transmission-remote -t all -S
            echo "All torrents paused"
            ;;
        6)
            transmission-remote -t all -s
            echo "All torrents resumed"
            ;;
        7)
            read -p "Enter download speed limit (KB/s, 0 for unlimited): " speed
            transmission-remote -d "$speed"
            echo "Download speed limit set to $speed KB/s"
            ;;
        8)
            read -p "Enter upload speed limit (KB/s, 0 for unlimited): " speed
            transmission-remote -u "$speed"
            echo "Upload speed limit set to $speed KB/s"
            ;;
        9)
            transmission-remote -l
            read -p "Enter torrent ID for details (or press Enter to skip): " id
            [ -n "$id" ] && transmission-remote -t "$id" -i
            ;;
        0)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
    clear
done
CONTROL_EOF

# Create sample torrent_list.txt
cat > /data/torrents/torrent_list.txt << 'TORRENT_LIST_EOF'
# Torrent List - Add magnet links, URLs, or file paths (one per line)
# Lines starting with # are ignored
#
# Example formats:
# magnet:?xt=urn:btih:HASH&dn=NAME
# http://example.com/file.torrent
# /path/to/local/file.torrent
#
# Add your torrent links below:
TORRENT_LIST_EOF

# Make all scripts executable
chmod +x /data/torrents/*.sh

echo ""
echo "✅ Installation Complete!"
echo ""
echo "📁 Files created in home directory:"
echo "   - torrent_manager.sh   : Main background service"
echo "   - monitor_torrents.sh  : Real-time progress monitor"
echo "   - start_torrents.sh    : Start the service"
echo "   - stop_torrents.sh     : Stop the service"
echo "   - torrent_control.sh   : Interactive control panel"
echo "   - torrent_list.txt     : Add your torrents here"
echo ""
echo "🚀 Quick Start:"
echo "   1. Add torrents to /data/torrents/torrent_list.txt"
echo "   2. Run: ./start_torrents.sh"
echo "   3. Monitor: ./monitor_torrents.sh"
echo ""
echo "📊 The system will:"
echo "   - Run in background (survives SSH logout)"
echo "   - Download all torrents simultaneously"
echo "   - Log everything to /data/torrents/torrent_logs/"
echo "   - Auto-remove completed torrents"
echo "   - Save downloads to /data/torrents/downloads/"
