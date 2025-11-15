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
                # Get file location before removing
                DOWNLOAD_DIR=$(transmission-remote -si | grep "Download directory" | cut -d: -f2- | xargs)
                FILE_INFO=$(transmission-remote -t "$id" -i 2>/dev/null)
                FILE_NAME=$(echo "$FILE_INFO" | grep "^ *Name:" | cut -d: -f2- | xargs)
                FILE_LOCATION=$(echo "$FILE_INFO" | grep "^ *Location:" | cut -d: -f2- | xargs)

                # Try transmission's built-in deletion first
                echo "Removing torrent and attempting to delete files..."
                transmission-remote -t "$id" --remove-and-delete

                # Wait a moment for transmission to process
                sleep 1

                # Check if files still exist and delete manually if needed
                if [ -n "$FILE_LOCATION" ] && [ -n "$FILE_NAME" ]; then
                    FULL_PATH="$FILE_LOCATION/$FILE_NAME"
                    if [ -e "$FULL_PATH" ]; then
                        echo "Transmission couldn't delete files. Deleting manually..."
                        rm -rf "$FULL_PATH"
                        if [ $? -eq 0 ]; then
                            echo -e "${GREEN}Files deleted successfully${NC}"
                        else
                            echo -e "${RED}Failed to delete files at: $FULL_PATH${NC}"
                            echo "You may need to delete manually with: rm -rf \"$FULL_PATH\""
                        fi
                    else
                        echo -e "${GREEN}Torrent and files removed successfully${NC}"
                    fi
                fi
            else
                transmission-remote -t "$id" -r
                echo -e "${GREEN}Torrent removed (files kept)${NC}"
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
