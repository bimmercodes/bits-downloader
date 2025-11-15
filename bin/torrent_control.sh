#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Cleanup function
cleanup() {
    echo -e "\n${GREEN}Exiting control panel...${NC}"
    exit 0
}

# Trap for clean exit
trap cleanup INT TERM

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

# Clear screen before starting
clear

while true; do
    show_menu
    read -p "Select option: " choice
    echo ""
    
    case $choice in
        1)
            read -p "Enter magnet link, URL, or file path: " torrent
            transmission-remote -a "$torrent"
            [ $? -eq 0 ] && echo -e "${GREEN}Torrent added successfully${NC}" || echo -e "${RED}Failed to add torrent${NC}"
            ;;
        2)
            transmission-remote -l
            echo ""
            read -p "Enter torrent ID to pause: " id
            if [ -n "$id" ]; then
                transmission-remote -t "$id" -S
                [ $? -eq 0 ] && echo -e "${GREEN}✓ Torrent $id paused${NC}" || echo -e "${RED}✗ Failed to pause torrent${NC}"
            else
                echo -e "${YELLOW}No ID entered${NC}"
            fi
            ;;
        3)
            transmission-remote -l
            echo ""
            read -p "Enter torrent ID to resume: " id
            if [ -n "$id" ]; then
                transmission-remote -t "$id" -s
                [ $? -eq 0 ] && echo -e "${GREEN}✓ Torrent $id resumed${NC}" || echo -e "${RED}✗ Failed to resume torrent${NC}"
            else
                echo -e "${YELLOW}No ID entered${NC}"
            fi
            ;;
        4)
            transmission-remote -l
            echo ""
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
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ All torrents paused${NC}"
            else
                echo -e "${RED}✗ Failed to pause torrents${NC}"
            fi
            ;;
        6)
            transmission-remote -t all -s
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ All torrents resumed${NC}"
            else
                echo -e "${RED}✗ Failed to resume torrents${NC}"
            fi
            ;;
        7)
            read -p "Enter download speed limit (KB/s, 0 for unlimited): " speed
            if [ -n "$speed" ]; then
                transmission-remote -d "$speed"
                [ $? -eq 0 ] && echo -e "${GREEN}✓ Download speed limit set to $speed KB/s${NC}" || echo -e "${RED}✗ Failed to set speed limit${NC}"
            else
                echo -e "${YELLOW}No speed entered${NC}"
            fi
            ;;
        8)
            read -p "Enter upload speed limit (KB/s, 0 for unlimited): " speed
            if [ -n "$speed" ]; then
                transmission-remote -u "$speed"
                [ $? -eq 0 ] && echo -e "${GREEN}✓ Upload speed limit set to $speed KB/s${NC}" || echo -e "${RED}✗ Failed to set speed limit${NC}"
            else
                echo -e "${YELLOW}No speed entered${NC}"
            fi
            ;;
        9)
            transmission-remote -l
            echo ""
            read -p "Enter torrent ID for details (or press Enter to skip): " id
            if [ -n "$id" ]; then
                echo ""
                transmission-remote -t "$id" -i
            fi
            ;;
        0)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            sleep 1
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
    clear
done
