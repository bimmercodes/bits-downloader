#!/bin/bash

# Transmission API Wrapper Library
# Single Responsibility: Handle all transmission-daemon operations
# DRY: Centralize transmission-remote commands
# Open/Closed: Easy to extend with new transmission operations

# Source dependencies
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/utils.sh"

# Check if transmission-daemon is installed
is_transmission_installed() {
    command -v transmission-daemon &> /dev/null
}

# Check if transmission-daemon is running
is_transmission_running() {
    transmission-remote -l &>/dev/null
}

# Start transmission-daemon with config
start_transmission() {
    local download_dir="$1"
    local incomplete_dir="$2"
    local log_file="$3"

    # Stop any existing instance
    stop_transmission 2>/dev/null

    # Start with configuration
    transmission-daemon \
        --download-dir "$download_dir" \
        --incomplete-dir "$incomplete_dir" \
        --logfile "$log_file" \
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

    is_transmission_running
}

# Ensure transmission is installed before attempting to control it
ensure_transmission_available() {
    if ! is_transmission_installed; then
        log_error "transmission-daemon is required but not installed. Please install transmission-cli and transmission-daemon." || true
        return 1
    fi
    return 0
}

# Stop transmission-daemon
stop_transmission() {
    if is_transmission_running; then
        transmission-daemon --stop 2>/dev/null
        sleep 2
        return 0
    fi
    return 1
}

# Get list of all torrents
get_torrent_list() {
    transmission-remote -l 2>/dev/null
}

# Get torrent info by ID
get_torrent_info() {
    local id="$1"
    transmission-remote -t "$id" -i 2>/dev/null
}

# Get session stats
get_session_stats() {
    transmission-remote -st 2>/dev/null
}

# Add torrent (magnet, URL, or file)
add_torrent() {
    local torrent="$1"
    local download_dir="${2:-}"

    if [ -n "$download_dir" ]; then
        transmission-remote -a "$torrent" -w "$download_dir" 2>&1
    else
        transmission-remote -a "$torrent" 2>&1
    fi

    return $?
}

# Remove torrent (keep files)
remove_torrent() {
    local id="$1"
    transmission-remote -t "$id" -r &>/dev/null
}

# Remove torrent and delete files
remove_torrent_with_files() {
    local id="$1"
    transmission-remote -t "$id" --remove-and-delete &>/dev/null
}

# Start torrent(s)
start_torrent() {
    local id="${1:-all}"
    transmission-remote -t "$id" -s &>/dev/null
}

# Stop torrent(s)
stop_torrent() {
    local id="${1:-all}"
    transmission-remote -t "$id" -S &>/dev/null
}

# Verify torrent
verify_torrent() {
    local id="$1"
    transmission-remote -t "$id" --verify &>/dev/null
}

# Set download speed limit (KB/s, 0 for unlimited)
set_download_speed() {
    local speed="$1"
    transmission-remote -d "$speed" &>/dev/null
}

# Set upload speed limit (KB/s, 0 for unlimited)
set_upload_speed() {
    local speed="$1"
    transmission-remote -u "$speed" &>/dev/null
}

# Get active torrent count
get_active_count() {
    get_torrent_list | grep -E "Downloading|Up & Down|Seeding" | wc -l
}

# Get stopped torrent count
get_stopped_count() {
    get_torrent_list | grep "Stopped" | wc -l
}

# Get total torrent count
get_total_count() {
    local list=$(get_torrent_list)
    if [ -n "$list" ]; then
        echo "$list" | tail -n 1 | awk '{print NF > 0 ? $1 : 0}' | grep -E '^[0-9]+$' || echo "0"
    else
        echo "0"
    fi
}

# Get download speed
get_download_speed() {
    get_session_stats | grep "Download Speed:" | awk '{print $3, $4}'
}

# Get upload speed
get_upload_speed() {
    get_session_stats | grep "Upload Speed:" | awk '{print $3, $4}'
}

# Get torrent field value
get_torrent_field() {
    local id="$1"
    local field="$2"

    local info=$(get_torrent_info "$id")

    case "$field" in
        name|NAME)
            echo "$info" | grep "^ *Name:" | cut -d: -f2- | xargs
            ;;
        percent|PERCENT)
            echo "$info" | grep "^ *Percent Done:" | awk '{print $3}'
            ;;
        size|SIZE|total_size)
            echo "$info" | grep "^ *Total size:" | awk '{print $3, $4}'
            ;;
        downloaded|DOWNLOADED|have)
            echo "$info" | grep "^ *Have:" | awk '{print $2, $3}'
            ;;
        eta|ETA)
            echo "$info" | grep "^ *ETA:" | cut -d: -f2- | xargs
            ;;
        download_speed|DOWNLOAD_SPEED)
            echo "$info" | grep "^ *Download Speed:" | awk '{print $3, $4}'
            ;;
        upload_speed|UPLOAD_SPEED)
            echo "$info" | grep "^ *Upload Speed:" | awk '{print $3, $4}'
            ;;
        peers|PEERS)
            echo "$info" | grep "^ *Peers:" | awk '{print $2}'
            ;;
        ratio|RATIO)
            echo "$info" | grep "^ *Ratio:" | awk '{print $2}'
            ;;
        status|STATUS)
            echo "$info" | grep "^ *State:" | cut -d: -f2- | xargs
            ;;
        location|LOCATION)
            echo "$info" | grep "^ *Location:" | cut -d: -f2- | xargs
            ;;
        *)
            return 1
            ;;
    esac
}

# Parse torrent list for easier processing
parse_torrent_list() {
    local filter="${1:-all}"  # all, active, stopped

    local list=$(get_torrent_list)

    while IFS= read -r line; do
        # Skip header and footer
        if [[ "$line" =~ ^[[:space:]]*ID || "$line" =~ ^Sum: ]]; then
            continue
        fi

        # Extract ID (first field, remove asterisk if present)
        local id=$(echo "$line" | awk '{print $1}' | tr -d '*')

        # Skip if not a valid ID
        if ! [[ "$id" =~ ^[0-9]+$ ]]; then
            continue
        fi

        # Apply filter
        case "$filter" in
            active)
                if ! echo "$line" | grep -qE "Downloading|Up & Down|Seeding"; then
                    continue
                fi
                ;;
            stopped)
                if ! echo "$line" | grep -q "Stopped"; then
                    continue
                fi
                ;;
        esac

        # Output ID for processing
        echo "$id"
    done <<< "$list"
}

# Check if torrent is complete
is_torrent_complete() {
    local id="$1"
    local percent=$(get_torrent_field "$id" "percent")

    if [[ "$percent" == "100%" ]]; then
        return 0
    else
        return 1
    fi
}

# Get completed torrents
get_completed_torrents() {
    parse_torrent_list | while read -r id; do
        if is_torrent_complete "$id"; then
            echo "$id"
        fi
    done
}
