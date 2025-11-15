#!/bin/bash

# Configuration Loader Library
# Single Responsibility: Load and provide configuration
# Dependency Inversion: All scripts depend on this abstraction

# Determine project root
if [ -n "$PROJECT_ROOT" ]; then
    CONFIG_PROJECT_ROOT="$PROJECT_ROOT"
elif [ -n "$BASH_SOURCE" ]; then
    LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    CONFIG_PROJECT_ROOT="$(cd "$LIB_DIR/.." && pwd)"
else
    CONFIG_PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fi

CONFIG_FILE="$CONFIG_PROJECT_ROOT/.config"

# Default configuration
declare -g TORRENT_DIR="$CONFIG_PROJECT_ROOT/torrents"
declare -g DOWNLOAD_DIR="$CONFIG_PROJECT_ROOT/downloads"
declare -g LOG_DIR="$CONFIG_PROJECT_ROOT/logs"
declare -g TORRENT_LIST="$CONFIG_PROJECT_ROOT/data/torrent_list.txt"

# Load configuration from file
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        return 0
    else
        return 1
    fi
}

# Save configuration to file
save_config() {
    cat > "$CONFIG_FILE" << EOF
TORRENT_DIR="$TORRENT_DIR"
DOWNLOAD_DIR="$DOWNLOAD_DIR"
LOG_DIR="$LOG_DIR"
TORRENT_LIST="$TORRENT_LIST"
EOF
}

# Get configuration value
get_config() {
    local key="$1"
    case "$key" in
        torrent_dir|TORRENT_DIR)
            echo "$TORRENT_DIR"
            ;;
        download_dir|DOWNLOAD_DIR)
            echo "$DOWNLOAD_DIR"
            ;;
        log_dir|LOG_DIR)
            echo "$LOG_DIR"
            ;;
        torrent_list|TORRENT_LIST)
            echo "$TORRENT_LIST"
            ;;
        project_root|PROJECT_ROOT)
            echo "$CONFIG_PROJECT_ROOT"
            ;;
        *)
            return 1
            ;;
    esac
}

# Ensure directories exist
ensure_directories() {
    mkdir -p "$TORRENT_DIR/added" "$DOWNLOAD_DIR/.incomplete" "$LOG_DIR"
}

# Auto-load configuration
load_config
