#!/bin/bash

# Torrent Control Panel - Interactive torrent management
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
    echo -e "\n${COLORS[GREEN]}Exiting control panel...${COLORS[RESET]}"
    exit 0
}

# Trap for clean exit
trap cleanup INT TERM

# Show menu (Single Responsibility)
show_menu() {
    print_separator "=" 45
    echo -e "${COLORS[GREEN]}     TORRENT CONTROL PANEL${COLORS[RESET]}"
    print_separator "=" 45
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
    print_separator "=" 45
}

# Add torrent handler (Single Responsibility)
handle_add_torrent() {
    read -p "Enter magnet link, URL, or file path: " torrent

    if [ -z "$torrent" ]; then
        print_warning "No torrent specified"
        return
    fi

    if add_torrent "$torrent" "$DOWNLOAD_DIR"; then
        print_success "Torrent added successfully"
    else
        print_error "Failed to add torrent"
    fi
}

# Pause torrent handler (Single Responsibility)
handle_pause_torrent() {
    get_torrent_list
    echo ""
    read -p "Enter torrent ID to pause: " id

    if [ -z "$id" ]; then
        print_warning "No ID entered"
        return
    fi

    if stop_torrent "$id"; then
        print_success "Torrent $id paused"
    else
        print_error "Failed to pause torrent"
    fi
}

# Resume torrent handler (Single Responsibility)
handle_resume_torrent() {
    get_torrent_list
    echo ""
    read -p "Enter torrent ID to resume: " id

    if [ -z "$id" ]; then
        print_warning "No ID entered"
        return
    fi

    if start_torrent "$id"; then
        print_success "Torrent $id resumed"
    else
        print_error "Failed to resume torrent"
    fi
}

# Remove torrent handler (Single Responsibility)
handle_remove_torrent() {
    get_torrent_list
    echo ""
    read -p "Enter torrent ID to remove: " id

    if [ -z "$id" ]; then
        print_warning "No ID entered"
        return
    fi

    read -p "Delete files too? (y/n): " delete

    if [ "$delete" = "y" ] || [ "$delete" = "Y" ]; then
        # Get file info before removing
        local name=$(get_torrent_field "$id" "name")

        if remove_torrent_with_files "$id"; then
            print_success "Torrent and files removed: $name"
        else
            print_error "Failed to remove torrent"
        fi
    else
        if remove_torrent "$id"; then
            print_success "Torrent removed (files kept)"
        else
            print_error "Failed to remove torrent"
        fi
    fi
}

# Set download speed handler (Single Responsibility)
handle_download_speed() {
    read -p "Enter download speed limit (KB/s, 0 for unlimited): " speed

    if [ -z "$speed" ]; then
        print_warning "No speed entered"
        return
    fi

    if set_download_speed "$speed"; then
        print_success "Download speed limit set to $speed KB/s"
    else
        print_error "Failed to set speed limit"
    fi
}

# Set upload speed handler (Single Responsibility)
handle_upload_speed() {
    read -p "Enter upload speed limit (KB/s, 0 for unlimited): " speed

    if [ -z "$speed" ]; then
        print_warning "No speed entered"
        return
    fi

    if set_upload_speed "$speed"; then
        print_success "Upload speed limit set to $speed KB/s"
    else
        print_error "Failed to set speed limit"
    fi
}

# Show detailed info handler (Single Responsibility)
handle_detailed_info() {
    get_torrent_list
    echo ""
    read -p "Enter torrent ID for details (or press Enter to skip): " id

    if [ -n "$id" ]; then
        echo ""
        get_torrent_info "$id"
    fi
}

# Main function
main() {
    # Check if transmission is running
    if ! is_transmission_running; then
        print_error "Transmission-daemon is not running!"
        echo "Start it with: ./bin/start_torrents.sh"
        exit 1
    fi

    # Clear screen before starting
    clear

    while true; do
        show_menu
        read -p "$(echo -e ${COLORS[WHITE]}Select option:${COLORS[RESET]} )" choice
        echo ""

        case $choice in
            1)
                handle_add_torrent
                ;;
            2)
                handle_pause_torrent
                ;;
            3)
                handle_resume_torrent
                ;;
            4)
                handle_remove_torrent
                ;;
            5)
                if stop_torrent "all"; then
                    print_success "All torrents paused"
                else
                    print_error "Failed to pause torrents"
                fi
                ;;
            6)
                if start_torrent "all"; then
                    print_success "All torrents resumed"
                else
                    print_error "Failed to resume torrents"
                fi
                ;;
            7)
                handle_download_speed
                ;;
            8)
                handle_upload_speed
                ;;
            9)
                handle_detailed_info
                ;;
            0)
                echo "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option"
                sleep 1
                ;;
        esac

        echo ""
        read -p "Press Enter to continue..."
        clear
    done
}

# Run main
main
