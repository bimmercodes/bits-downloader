#!/bin/bash

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$BIN_DIR/.." && pwd)"
LOG_DIR="/data/bimmercodes/bits-downloader/logs"
DOWNLOAD_DIR="/data/downloads"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Function to show detailed torrent info
show_detailed_info() {
    local ID=$1

    echo -e "\n${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}             DETAILED TORRENT INFORMATION${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}\n"

    transmission-remote -t "$ID" -i 2>/dev/null

    echo -e "\n${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    read -p "Press Enter to return to monitor..."
}

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

# Trap Ctrl+C to handle detailed view request
trap 'read -t 0.1 -n 1 key && [ "$key" = "d" ] && read -p "Enter torrent ID for details: " detail_id && [ -n "$detail_id" ] && show_detailed_info "$detail_id"' INT

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

    ACTIVE_COUNT=0
    while IFS= read -r line; do
        if echo "$line" | grep -qE "Downloading|Up & Down|Seeding"; then
            ID=$(echo "$line" | awk '{print $1}' | tr -d '*')

            # Get detailed info for this torrent
            INFO=$(transmission-remote -t "$ID" -i 2>/dev/null)

            NAME=$(echo "$INFO" | grep "^ *Name:" | cut -d: -f2- | xargs)
            PERCENT=$(echo "$INFO" | grep "^ *Percent Done:" | awk '{print $3}')
            TOTAL_SIZE=$(echo "$INFO" | grep "^ *Total size:" | awk '{print $3, $4}')
            DOWNLOADED=$(echo "$INFO" | grep "^ *Have:" | awk '{print $2, $3}')
            ETA=$(echo "$INFO" | grep "^ *ETA:" | cut -d: -f2- | xargs)
            DOWNLOAD_SPEED=$(echo "$INFO" | grep "^ *Download Speed:" | awk '{print $3, $4}')
            PEERS=$(echo "$INFO" | grep "^ *Peers:" | awk '{print $2}')

            # Truncate name if too long
            if [ ${#NAME} -gt 45 ]; then
                NAME="${NAME:0:42}..."
            fi

            # Display with more details
            printf "${MAGENTA}ID:${NC} %-3s ${CYAN}%-45s${NC}\n" "$ID" "$NAME"
            printf "      Progress: ${GREEN}%s${NC}  Downloaded: ${YELLOW}%s${NC} / ${YELLOW}%s${NC}\n" "$PERCENT" "$DOWNLOADED" "$TOTAL_SIZE"
            printf "      Speed: ${BLUE}%s${NC}  ETA: ${CYAN}%s${NC}  Peers: ${GREEN}%s${NC}\n\n" "$DOWNLOAD_SPEED" "$ETA" "$PEERS"

            ((ACTIVE_COUNT++))
        fi
    done <<< "$STATUS"

    [ $ACTIVE_COUNT -eq 0 ] && echo -e "None\n"
    
    # Queued torrents
    echo -e "${YELLOW}QUEUED:${NC}"
    echo "─────────────────────────────────────────────────────────────────"

    QUEUED_COUNT=0
    while IFS= read -r line; do
        if echo "$line" | grep -q "Stopped"; then
            ID=$(echo "$line" | awk '{print $1}' | tr -d '*')
            INFO=$(transmission-remote -t "$ID" -i 2>/dev/null)
            NAME=$(echo "$INFO" | grep "^ *Name:" | cut -d: -f2- | xargs)
            PERCENT=$(echo "$INFO" | grep "^ *Percent Done:" | awk '{print $3}')
            TOTAL_SIZE=$(echo "$INFO" | grep "^ *Total size:" | awk '{print $3, $4}')

            if [ ${#NAME} -gt 45 ]; then
                NAME="${NAME:0:42}..."
            fi

            printf "${MAGENTA}ID:${NC} %-3s ${CYAN}%-45s${NC} [%s - %s]\n" "$ID" "$NAME" "$PERCENT" "$TOTAL_SIZE"
            ((QUEUED_COUNT++))
        fi
    done <<< "$STATUS"

    [ $QUEUED_COUNT -eq 0 ] && echo -e "None\n"

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
    echo -e "Press ${CYAN}Ctrl+C then 'd'${NC} for detailed view | ${CYAN}Ctrl+C twice${NC} to exit | Refreshing every 5 seconds..."

    sleep 5
done
