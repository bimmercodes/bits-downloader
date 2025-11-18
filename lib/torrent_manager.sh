#!/bin/bash

# Torrent Manager - Main Background Service
# Refactored with SOLID and DRY principles

set -euo pipefail
IFS=$'\n\t'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries (Dependency Inversion Principle)
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/transmission_api.sh"

# Constants
readonly PID_FILE="/tmp/torrent_manager.pid"
readonly MAIN_LOG="$LOG_DIR/torrent_manager.log"

# Logging wrapper (DRY)
log_message() {
    log_info "$1" "$MAIN_LOG"
}

# Ensure directories exist
ensure_directories
log_message "Ensured base directories exist"

# Check if already running (Single Responsibility)
check_already_running() {
    if [ -f "$PID_FILE" ]; then
        local old_pid=$(cat "$PID_FILE")
        if ps -p "$old_pid" > /dev/null 2>&1; then
            log_error "Torrent manager already running with PID $old_pid" "$MAIN_LOG"
            exit 1
        else
            rm -f "$PID_FILE"
        fi
    fi
}

# Cleanup on exit
cleanup() {
    rm -f "$PID_FILE"
    log_message "Torrent manager stopped"
}

# Process torrents from list file (Single Responsibility)
process_torrent_list() {
    if [ ! -f "$TORRENT_LIST" ]; then
        return 0
    fi

    log_message "Processing torrents from list: $TORRENT_LIST"

    while IFS= read -r torrent; do
        # Skip empty lines and comments
        [ -z "$torrent" ] || [[ "$torrent" =~ ^# ]] && continue

        # Add torrent based on type
        if [[ "$torrent" =~ ^magnet: ]] || [[ "$torrent" =~ ^http ]]; then
            if add_torrent "$torrent" "$DOWNLOAD_DIR" &>/dev/null; then
                log_success "Added: $torrent" "$MAIN_LOG"
            else
                log_error "Failed to add: $torrent" "$MAIN_LOG"
            fi
        elif [ -f "$torrent" ]; then
            if add_torrent "$torrent" "$DOWNLOAD_DIR" &>/dev/null; then
                log_success "Added file: $torrent" "$MAIN_LOG"
            else
                log_error "Failed to add file: $torrent" "$MAIN_LOG"
            fi
        fi
    done < "$TORRENT_LIST"
}

# Process torrent files from directory (Single Responsibility)
process_torrent_files() {
    local torrent_file

    for torrent_file in "$TORRENT_DIR"/*.torrent; do
        [ -f "$torrent_file" ] || continue

        if add_torrent "$torrent_file" "$DOWNLOAD_DIR" &>/dev/null; then
            log_success "Added torrent file: $(basename "$torrent_file")" "$MAIN_LOG"
            mv "$torrent_file" "$TORRENT_DIR/added/"
        else
            log_error "Failed to add: $(basename "$torrent_file")" "$MAIN_LOG"
        fi
    done
}

# Monitor and manage torrents (Single Responsibility)
monitor_torrents() {
    local completed_log="$LOG_DIR/completed.log"
    local status_file="$LOG_DIR/current_status.txt"

    while true; do
        # Check if transmission is still running
        if ! is_transmission_running; then
            log_warning "Cannot connect to transmission-daemon" "$MAIN_LOG"
            sleep 30
            continue
        fi

        # Get current status
        local status=$(get_torrent_list)
        local active=$(get_active_count)
        local total=$(get_total_count)

        # Log summary
        log_message "Status: Active: $active | Total in queue: $total"

        # Save detailed status
        echo "$status" > "$status_file"

        # Process completed torrents
        while read -r id; do
            local name=$(get_torrent_field "$id" "name")

            if [ -n "$name" ]; then
                log_success "COMPLETED: $name" "$completed_log"
                log_message "Removing completed torrent (files kept): $name"

                # Remove torrent but keep files
                remove_torrent "$id"
            fi
        done < <(get_completed_torrents)

        # Sleep for 5 minutes before next check
        sleep 300
    done
}

# Main function (orchestrates the flow)
main() {
    # Setup
    trap cleanup EXIT INT TERM

    if ! ensure_transmission_available; then
        log_error "transmission-daemon is not installed. Aborting background manager startup." "$MAIN_LOG"
        exit 1
    fi

    # Check if already running
    check_already_running

    # Save PID
    echo $$ > "$PID_FILE"

    log_message "Starting torrent manager..."
    log_message "Download directory: $DOWNLOAD_DIR"
    log_message "Torrent directory: $TORRENT_DIR"

    # Start transmission-daemon
    if start_transmission "$DOWNLOAD_DIR" "$DOWNLOAD_DIR/.incomplete" "$LOG_DIR/transmission.log"; then
        log_success "Transmission-daemon started successfully" "$MAIN_LOG"
    else
        log_error "Failed to start transmission-daemon" "$MAIN_LOG"
        exit 1
    fi

    # Process torrents from list
    process_torrent_list

    # Process torrent files
    process_torrent_files

    # Start all torrents
    start_torrent "all"
    log_message "Started all torrents"

    # Enter monitoring loop
    monitor_torrents
}

# Run main
main
