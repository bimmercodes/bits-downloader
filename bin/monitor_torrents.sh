#!/bin/bash

# Torrent Monitor - Interactive torrent monitoring interface
# Refactored with SOLID and DRY principles

# Get script directory and project root
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$BIN_DIR/.." && pwd)"

# Source libraries
source "$PROJECT_ROOT/lib/config.sh"
source "$PROJECT_ROOT/lib/utils.sh"
source "$PROJECT_ROOT/lib/transmission_api.sh"

# Cleanup function
cleanup() {
    cleanup_terminal
    echo -e "\n${COLORS[GREEN]}Monitor stopped. Returning to menu...${COLORS[RESET]}"
    exit 0
}

# Trap for clean exit
trap cleanup INT TERM EXIT

# Function to show detailed torrent info (Single Responsibility)
show_detailed_info() {
    local id=$1

    clear
    print_separator "=" 65
    echo -e "${COLORS[CYAN]}             DETAILED TORRENT INFORMATION${COLORS[RESET]}"
    print_separator "=" 65
    echo ""

    if get_torrent_info "$id"; then
        echo ""
    else
        print_error "Invalid torrent ID or torrent not found"
    fi

    echo ""
    print_separator "=" 65
    read -p "Press Enter to return to monitor..."
    # Clear any extra input
    read -t 0.1 -n 10000 discard 2>/dev/null || true
}

# Display active torrents (Single Responsibility)
display_active_torrents() {
    echo -e "${COLORS[GREEN]}ACTIVE DOWNLOADS:${COLORS[RESET]}"
    print_separator "-" 65

    local active_count=0

    while read -r id; do
        local name=$(get_torrent_field "$id" "name")
        local percent=$(get_torrent_field "$id" "percent")
        local total_size=$(get_torrent_field "$id" "size")
        local downloaded=$(get_torrent_field "$id" "downloaded")
        local eta=$(get_torrent_field "$id" "eta")
        local download_speed=$(get_torrent_field "$id" "download_speed")
        local peers=$(get_torrent_field "$id" "peers")

        # Truncate name if too long
        if [ ${#name} -gt 45 ]; then
            name="${name:0:42}..."
        fi

        # Display with details
        printf "${COLORS[MAGENTA]}ID:${COLORS[RESET]} %-3s ${COLORS[CYAN]}%-45s${COLORS[RESET]}\n" "$id" "$name"
        printf "      Progress: ${COLORS[GREEN]}%s${COLORS[RESET]}  Downloaded: ${COLORS[YELLOW]}%s${COLORS[RESET]} / ${COLORS[YELLOW]}%s${COLORS[RESET]}\n" "$percent" "$downloaded" "$total_size"
        printf "      Speed: ${COLORS[BLUE]}%s${COLORS[RESET]}  ETA: ${COLORS[CYAN]}%s${COLORS[RESET]}  Peers: ${COLORS[GREEN]}%s${COLORS[RESET]}\n\n" "$download_speed" "$eta" "$peers"

        ((active_count++))
    done < <(parse_torrent_list "active")

    [ $active_count -eq 0 ] && echo -e "None\n"
}

# Display queued torrents (Single Responsibility)
display_queued_torrents() {
    echo -e "${COLORS[YELLOW]}QUEUED:${COLORS[RESET]}"
    print_separator "-" 65

    local queued_count=0

    while read -r id; do
        local name=$(get_torrent_field "$id" "name")
        local percent=$(get_torrent_field "$id" "percent")
        local total_size=$(get_torrent_field "$id" "size")

        if [ ${#name} -gt 45 ]; then
            name="${name:0:42}..."
        fi

        printf "${COLORS[MAGENTA]}ID:${COLORS[RESET]} %-3s ${COLORS[CYAN]}%-45s${COLORS[RESET]} [%s - %s]\n" "$id" "$name" "$percent" "$total_size"
        ((queued_count++))
    done < <(parse_torrent_list "stopped")

    [ $queued_count -eq 0 ] && echo -e "None\n"
}

# Display completed torrents (Single Responsibility)
display_completed() {
    echo -e "\n${COLORS[GREEN]}RECENTLY COMPLETED:${COLORS[RESET]}"
    print_separator "-" 65

    if [ -f "$LOG_DIR/completed.log" ]; then
        tail -n 5 "$LOG_DIR/completed.log" 2>/dev/null || echo "None"
    else
        echo "None"
    fi
}

# Display disk usage (Single Responsibility)
display_disk_usage() {
    echo -e "\n${COLORS[BLUE]}DISK USAGE (Download Directory: $DOWNLOAD_DIR):${COLORS[RESET]}"

    if [ -d "$DOWNLOAD_DIR" ]; then
        df -h "$DOWNLOAD_DIR" 2>/dev/null | tail -n 1 | awk '{printf "Used: %s/%s (%s) - Available: %s\n", $3, $2, $5, $4}'
    else
        print_warning "Download directory not found: $DOWNLOAD_DIR"
    fi
}

# Main monitoring function
main() {
    clear

    print_separator "=" 65
    echo -e "${COLORS[GREEN]}         TORRENT DOWNLOAD MONITOR${COLORS[RESET]}"
    print_separator "=" 65

    # Check if transmission-daemon is running
    if ! is_transmission_running; then
        print_error "Transmission-daemon is not running!"
        echo "Start it with: ./bin/start_torrents.sh"
        exit 1
    fi

    while true; do
        clear

        print_separator "=" 65
        echo -e "${COLORS[GREEN]}         TORRENT DOWNLOAD MONITOR - $(date '+%H:%M:%S')${COLORS[RESET]}"
        print_separator "=" 65
        echo ""

        # Get and display speeds
        local download_speed=$(get_download_speed)
        local upload_speed=$(get_upload_speed)
        echo -e "${COLORS[YELLOW]}SPEEDS:${COLORS[RESET]} ↓ $download_speed  ↑ $upload_speed\n"

        # Display sections
        display_active_torrents
        display_queued_torrents
        display_completed
        display_disk_usage

        echo ""
        print_separator "=" 65
        echo -e "Press ${COLORS[CYAN]}'d'${COLORS[RESET]} for detailed view | ${COLORS[CYAN]}'q' or Ctrl+C${COLORS[RESET]} to exit | Auto-refresh in 5s..."

        # Check for user input (non-blocking with 5 second timeout)
        read -t 5 -n 1 key 2>/dev/null
        local response=$?

        # Only process if a key was actually pressed (exit status 0)
        if [ $response -eq 0 ]; then
            case "$key" in
                q|Q)
                    cleanup
                    ;;
                d|D)
                    echo ""
                    read -p "Enter torrent ID for details: " detail_id
                    if [ -n "$detail_id" ]; then
                        show_detailed_info "$detail_id"
                    fi
                    ;;
                *)
                    # Clear any other input
                    read -t 0.1 -n 10000 discard 2>/dev/null || true
                    ;;
            esac
        fi
    done
}

# Run main
main
