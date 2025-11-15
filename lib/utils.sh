#!/bin/bash

# Utilities Library
# Single Responsibility: Provide common utilities (colors, logging, display)
# DRY: Centralize repeated code

# Color definitions (associative array for better organization)
declare -gA COLORS=(
    [RESET]='\033[0m'
    [BOLD]='\033[1m'
    [DIM]='\033[2m'
    [RED]='\033[0;31m'
    [GREEN]='\033[0;32m'
    [YELLOW]='\033[1;33m'
    [BLUE]='\033[0;34m'
    [MAGENTA]='\033[0;35m'
    [CYAN]='\033[0;36m'
    [WHITE]='\033[1;37m'
    [GRAY]='\033[0;90m'
    [BG_BLACK]='\033[40m'
    [BG_BLUE]='\033[44m'
    [BG_CYAN]='\033[46m'
)

# Legacy color variables for backward compatibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

# Terminal control codes
CLEAR_SCREEN='\033[2J'
CURSOR_HOME='\033[H'
HIDE_CURSOR='\033[?25l'
SHOW_CURSOR='\033[?25h'
SAVE_CURSOR='\033[s'
RESTORE_CURSOR='\033[u'

# Logging functions
log_info() {
    local message="$1"
    local log_file="${2:-}"
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"

    if [ -n "$log_file" ]; then
        echo "$timestamp INFO: $message" | tee -a "$log_file"
    else
        echo -e "${COLORS[CYAN]}$timestamp INFO: $message${COLORS[RESET]}"
    fi
}

log_success() {
    local message="$1"
    local log_file="${2:-}"
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"

    if [ -n "$log_file" ]; then
        echo "$timestamp SUCCESS: $message" | tee -a "$log_file"
    else
        echo -e "${COLORS[GREEN]}$timestamp SUCCESS: $message${COLORS[RESET]}"
    fi
}

log_warning() {
    local message="$1"
    local log_file="${2:-}"
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"

    if [ -n "$log_file" ]; then
        echo "$timestamp WARNING: $message" | tee -a "$log_file"
    else
        echo -e "${COLORS[YELLOW]}$timestamp WARNING: $message${COLORS[RESET]}"
    fi
}

log_error() {
    local message="$1"
    local log_file="${2:-}"
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"

    if [ -n "$log_file" ]; then
        echo "$timestamp ERROR: $message" | tee -a "$log_file"
    else
        echo -e "${COLORS[RED]}$timestamp ERROR: $message${COLORS[RESET]}"
    fi
}

# Display helpers
print_header() {
    local title="$1"
    local width="${2:-60}"

    echo -e "${COLORS[CYAN]}╔$(printf '═%.0s' $(seq 1 $((width - 2))))╗${COLORS[RESET]}"

    local padding=$(( (width - ${#title} - 2) / 2 ))
    printf "${COLORS[CYAN]}║${COLORS[RESET]}"
    printf "%${padding}s" ""
    printf "${COLORS[WHITE]}${COLORS[BOLD]}%s${COLORS[RESET]}" "$title"
    printf "%$((width - padding - ${#title} - 2))s" ""
    printf "${COLORS[CYAN]}║${COLORS[RESET]}\n"

    echo -e "${COLORS[CYAN]}╚$(printf '═%.0s' $(seq 1 $((width - 2))))╝${COLORS[RESET]}"
}

print_separator() {
    local char="${1:--}"
    local width="${2:-60}"

    echo -e "${COLORS[BLUE]}$(printf '%*s' "$width" '' | tr ' ' "$char")${COLORS[RESET]}"
}

print_success() {
    echo -e "${COLORS[GREEN]}✓${COLORS[RESET]} $1"
}

print_error() {
    echo -e "${COLORS[RED]}✗${COLORS[RESET]} $1"
}

print_warning() {
    echo -e "${COLORS[YELLOW]}⚠${COLORS[RESET]} $1"
}

print_info() {
    echo -e "${COLORS[CYAN]}ℹ${COLORS[RESET]} $1"
}

# Format bytes to human readable
format_bytes() {
    local bytes="$1"

    if [ -z "$bytes" ] || [ "$bytes" = "0" ]; then
        echo "0 B"
        return
    fi

    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    local size=$bytes

    while [ $(echo "$size >= 1024" | bc 2>/dev/null || echo 0) -eq 1 ] && [ $unit -lt 4 ]; do
        size=$(echo "scale=2; $size / 1024" | bc)
        ((unit++))
    done

    echo "$size ${units[$unit]}"
}

# Get terminal size
get_terminal_size() {
    TERM_HEIGHT=$(tput lines 2>/dev/null || echo 24)
    TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)
}

# Draw horizontal line
draw_line() {
    local char="${1:--}"
    local width="${2:-$TERM_WIDTH}"
    printf "%${width}s" | tr ' ' "$char"
}

# Center text
center_text() {
    local text="$1"
    local width="${2:-$TERM_WIDTH}"
    local padding=$(( (width - ${#text}) / 2 ))
    printf "%${padding}s%s" "" "$text"
}

# Cleanup handler for terminal
cleanup_terminal() {
    echo -ne "${SHOW_CURSOR}"
    stty echo 2>/dev/null
    tput cnorm 2>/dev/null
}

# Prompt for confirmation
confirm() {
    local prompt="$1"
    local default="${2:-n}"

    if [ "$default" = "y" ]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi

    read -p "$(echo -e ${COLORS[YELLOW]}$prompt${COLORS[RESET]})" response

    if [ -z "$response" ]; then
        response="$default"
    fi

    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Show spinner animation
show_spinner() {
    local pid=$1
    local message="${2:-Processing...}"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0

    tput civis 2>/dev/null

    while kill -0 $pid 2>/dev/null; do
        printf "\r${COLORS[CYAN]}${frames[$i]}${COLORS[RESET]} $message"
        i=$(( (i + 1) % ${#frames[@]} ))
        sleep 0.1
    done

    printf "\r%*s\r" $((${#message} + 3)) ""
    tput cnorm 2>/dev/null
}
