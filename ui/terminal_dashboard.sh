#!/bin/bash

# Full-Screen Responsive Terminal Dashboard
# Refactored with SOLID and DRY principles

# Path configuration
UI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$UI_DIR/.." && pwd)"

# Source libraries
source "$PROJECT_ROOT/lib/config.sh"
source "$PROJECT_ROOT/lib/utils.sh"
source "$PROJECT_ROOT/lib/transmission_api.sh"

# Global variables
TERM_WIDTH=0
TERM_HEIGHT=0
NEED_REDRAW=1
RUNNING=1
FIRST_DRAW=1
LAST_REFRESH=0
SCROLL_OFFSET=0
TORRENT_TOTAL_LINES=0
TORRENT_VIEW_HEIGHT=0
SELECTED_INDEX=0
REFRESH_TORRENTS=1
declare -a TORRENT_CACHE=()
HEADER_LINE=""

# Get terminal dimensions
get_terminal_size() {
    TERM_HEIGHT=$(tput lines)
    TERM_WIDTH=$(tput cols)
}

# Draw box with title
draw_box() {
    local title="$1"
    local y=$2
    local x=$3
    local width=$4
    local height=$5

    # Top border
    tput cup $y $x
    echo -n "+"
    draw_line "-" $((width - 2))
    echo -n "+"

    # Title
    if [ -n "$title" ]; then
        local title_pos=$(( (width - ${#title} - 2) / 2 ))
        tput cup $y $((x + title_pos))
        echo -n "[ $title ]"
    fi

    # Sides
    for ((i=1; i<height-1; i++)); do
        tput cup $((y + i)) $x
        echo -n "|"
        tput cup $((y + i)) $((x + width - 1))
        echo -n "|"
    done

    # Bottom border
    tput cup $((y + height - 1)) $x
    echo -n "+"
    draw_line "-" $((width - 2))
    echo -n "+"
}

# Draw header
draw_header() {
    local title="*** BITS TORRENT DOWNLOADER DASHBOARD ***"
    local subtitle="Real-time Monitoring - Terminal: ${TERM_WIDTH}x${TERM_HEIGHT} - Download: ${DOWNLOAD_DIR}"

    # Row 0: title on blue
    echo -ne "${COLORS[BG_BLUE]}${COLORS[WHITE]}${COLORS[BOLD]}"
    printf "%${TERM_WIDTH}s" " "
    local title_pos=$(( (TERM_WIDTH - ${#title}) / 2 ))
    [ $title_pos -lt 0 ] && title_pos=0
    tput cup 0 $title_pos
    echo -n "$title"

    # Row 1: subtitle on blue
    tput cup 1 0
    echo -ne "${COLORS[BG_BLUE]}${COLORS[CYAN]}${COLORS[DIM]}"
    printf "%${TERM_WIDTH}s" " "
    local subtitle_pos=$(( (TERM_WIDTH - ${#subtitle}) / 2 ))
    [ $subtitle_pos -lt 0 ] && subtitle_pos=0
    tput cup 1 $subtitle_pos
    echo -n "$subtitle"

    # Separator line
    tput cup 2 0
    echo -ne "${COLORS[BLUE]}"
    draw_line "=" $TERM_WIDTH
    echo -ne "${COLORS[RESET]}"
}

# Draw footer
draw_footer() {
    local footer_y=$((TERM_HEIGHT - 2))

    # Footer content
    tput cup $footer_y 0
    echo -ne "${COLORS[BG_BLACK]}${COLORS[CYAN]}"
    printf "%${TERM_WIDTH}s" " "

    local footer_text=""
    local footer_pos=$(( (TERM_WIDTH - ${#footer_text}) / 2 ))
    tput cup $footer_y $footer_pos
    echo -n "$footer_text"

    # Status bar
    tput cup $((footer_y + 1)) 0
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Show transmission status
    if is_transmission_running; then
        echo -ne "${COLORS[GREEN]}"
        echo -n "> Status: RUNNING"
    else
        echo -ne "${COLORS[RED]}"
        echo -n "> Status: STOPPED"
    fi

    tput cup $((footer_y + 1)) $((TERM_WIDTH - ${#timestamp} - 1))
    echo -n "$timestamp"
    echo -ne "${COLORS[RESET]}"
}

# Get torrent stats
get_torrent_stats() {
    if is_transmission_running; then
        get_torrent_list
    else
        echo "Transmission daemon not running"
    fi
}

# Draw torrent list
draw_torrent_section() {
    local box_y=3
    local box_x=1
    local box_width=$((TERM_WIDTH - 2))
    local details_height=14
    local box_height=$((TERM_HEIGHT - 9 - details_height))

    [ $box_height -lt 5 ] && box_height=5

    draw_box "ACTIVE TORRENTS" $box_y $box_x $box_width $box_height

    # Content area
    local content_y=$((box_y + 1))
    local content_x=$((box_x + 2))
    local content_width=$((box_width - 4))
    local content_height=$((box_height - 2))

    TORRENT_VIEW_HEIGHT=$content_height

    # Refresh torrent data only when needed (avoid lag on scroll)
    if [ $REFRESH_TORRENTS -eq 1 ]; then
        mapfile -t raw_torrents < <(get_torrent_stats)
        HEADER_LINE="${raw_torrents[0]}"

        TORRENT_CACHE=()
        for ((i=1; i<${#raw_torrents[@]}; i++)); do
            line="${raw_torrents[$i]}"
            [[ "$line" =~ ^Sum: ]] && continue
            TORRENT_CACHE+=("$line")
        done

        TORRENT_TOTAL_LINES=${#TORRENT_CACHE[@]}
        REFRESH_TORRENTS=0
    fi

    # Clamp selection and scroll to available lines
    if [ $TORRENT_TOTAL_LINES -eq 0 ]; then
        SELECTED_INDEX=0
        SCROLL_OFFSET=0
    else
        (( SELECTED_INDEX < 0 )) && SELECTED_INDEX=0
        (( SELECTED_INDEX >= TORRENT_TOTAL_LINES )) && SELECTED_INDEX=$((TORRENT_TOTAL_LINES - 1))
    fi

    # Clamp scroll offset to available lines
    # The first row is reserved for the header line
    local list_height=$((content_height - 1))
    (( list_height < 1 )) && list_height=1

    local max_offset=$((TORRENT_TOTAL_LINES - list_height))
    (( max_offset < 0 )) && max_offset=0
    (( SCROLL_OFFSET > max_offset )) && SCROLL_OFFSET=$max_offset

    # Ensure selected index is visible
    if [ $SELECTED_INDEX -lt $SCROLL_OFFSET ]; then
        SCROLL_OFFSET=$SELECTED_INDEX
    elif [ $SELECTED_INDEX -ge $((SCROLL_OFFSET + list_height)) ]; then
        SCROLL_OFFSET=$((SELECTED_INDEX - list_height + 1))
    fi

    # Render header line
    tput cup $content_y $content_x
    echo -ne "${COLORS[WHITE]}${COLORS[BOLD]}"
    printf "%-${content_width}s" "${HEADER_LINE:0:$content_width}"
    echo -ne "${COLORS[RESET]}"

    # Render visible window with scroll offset and selection (excluding header)
    for ((i=0; i<list_height; i++)); do
        tput cup $((content_y + 1 + i)) $content_x
        local idx=$((i + SCROLL_OFFSET))

        if [ $idx -lt $TORRENT_TOTAL_LINES ]; then
            local line="${TORRENT_CACHE[$idx]}"

            # Colorize based on status
            if [[ "$line" =~ "100%" ]] || [[ "$line" =~ "Seeding" ]]; then
                echo -ne "${COLORS[GREEN]}"
            elif [[ "$line" =~ "Downloading" ]] || [[ "$line" =~ "Up & Down" ]]; then
                echo -ne "${COLORS[YELLOW]}"
            elif [[ "$line" =~ "Stopped" ]] || [[ "$line" =~ "Idle" ]]; then
                echo -ne "${COLORS[RED]}"
            else
                echo -ne "${COLORS[CYAN]}"
            fi

            # Highlight selected row
            if [ $idx -eq $SELECTED_INDEX ]; then
                echo -ne "${COLORS[BG_CYAN]}${COLORS[BLUE]}"
            fi

            # Truncate line to fit
            local display_line="${line:0:$content_width}"
            printf "%-${content_width}s" "$display_line"
            echo -ne "${COLORS[RESET]}"
        else
            printf "%${content_width}s" " "
        fi
    done
}

# Draw torrent details for selected torrent
draw_torrent_details() {
    local details_height=14
    local box_width=$((TERM_WIDTH - 2))
    local box_x=1
    local box_y=$((TERM_HEIGHT - details_height - 6)) # sit above stats/footer area
    [ $box_y -lt 4 ] && box_y=4

    draw_box "TORRENT DETAILS" $box_y $box_x $box_width $details_height

    local content_y=$((box_y + 1))
    local content_x=$((box_x + 2))
    local content_width=$((box_width - 4))

    if [ $TORRENT_TOTAL_LINES -eq 0 ]; then
        tput cup $content_y $content_x
        echo -ne "${COLORS[RED]}No torrents to display${COLORS[RESET]}"
        return
    fi

    local id_field name percent size have eta status location ratio uploaded downloaded

    local selected_line="${TORRENT_CACHE[$SELECTED_INDEX]}"
    id_field=$(echo "$selected_line" | awk '{print $1}')

    name=$(get_torrent_field "$id_field" "name")
    percent=$(get_torrent_field "$id_field" "percent")
    size=$(get_torrent_field "$id_field" "size")
    have=$(get_torrent_field "$id_field" "downloaded")
    eta=$(get_torrent_field "$id_field" "eta")
    status=$(get_torrent_field "$id_field" "status")
    location=$(get_torrent_field "$id_field" "location")
    ratio=$(get_torrent_field "$id_field" "ratio")
    uploaded=$(get_torrent_field "$id_field" "upload_speed")
    downloaded=$(get_torrent_field "$id_field" "download_speed")

    local line

    tput cup $content_y $content_x
    line=$(printf "${COLORS[CYAN]}ID:${COLORS[RESET]} %s  ${COLORS[CYAN]}Name:${COLORS[RESET]} %s" "$id_field" "${name:0:$((content_width - 20))}")
    printf "%-${content_width}s" "$line"

    tput cup $((content_y + 1)) $content_x
    line=$(printf "${COLORS[CYAN]}Progress:${COLORS[RESET]} %s  ${COLORS[CYAN]}Total:${COLORS[RESET]} %s  ${COLORS[CYAN]}Have:${COLORS[RESET]} %s" "${percent:-N/A}" "${size:-N/A}" "${have:-N/A}")
    printf "%-${content_width}s" "$line"

    tput cup $((content_y + 2)) $content_x
    line=$(printf "${COLORS[CYAN]}ETA:${COLORS[RESET]} %s  ${COLORS[CYAN]}Status:${COLORS[RESET]} %s  ${COLORS[CYAN]}Ratio:${COLORS[RESET]} %s" "${eta:-N/A}" "${status:-N/A}" "${ratio:-N/A}")
    printf "%-${content_width}s" "$line"

    tput cup $((content_y + 3)) $content_x
    line=$(printf "${COLORS[CYAN]}Speeds:${COLORS[RESET]} ↓ %s  ↑ %s" "${downloaded:-N/A}" "${uploaded:-N/A}")
    printf "%-${content_width}s" "$line"

    tput cup $((content_y + 4)) $content_x
    line=$(printf "${COLORS[CYAN]}Location:${COLORS[RESET]} %s" "${location:0:$content_width}")
    printf "%-${content_width}s" "$line"
}

# Draw stats section
draw_stats_section() {
    local stats_y=$((TERM_HEIGHT - 6))
    local stats_height=4

    # Three columns for stats
    local col_width=$((TERM_WIDTH / 3))

    # Download stats
    draw_box "DOWNLOADS" $stats_y 1 $col_width $stats_height
    tput cup $((stats_y + 1)) 3

    if [ -d "$DOWNLOAD_DIR" ]; then
        local dl_count=$(find "$DOWNLOAD_DIR" -type f 2>/dev/null | wc -l)
        echo -ne "${COLORS[GREEN]}Files: $dl_count${COLORS[RESET]}"
        tput cup $((stats_y + 2)) 3
        local dl_size=$(du -sh "$DOWNLOAD_DIR" 2>/dev/null | cut -f1)
        echo -ne "${COLORS[CYAN]}Size: ${dl_size:-0}${COLORS[RESET]}"
    else
        echo -ne "${COLORS[RED]}Dir not found${COLORS[RESET]}"
    fi

    # System stats
    draw_box "SYSTEM" $stats_y $((col_width + 1)) $col_width $stats_height
    tput cup $((stats_y + 1)) $((col_width + 3))
    local cpu_load=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d, -f1 | xargs)
    echo -ne "${COLORS[YELLOW]}Load: $cpu_load${COLORS[RESET]}"
    tput cup $((stats_y + 2)) $((col_width + 3))
    local mem_usage=$(free -h 2>/dev/null | awk '/^Mem:/ {print $3 "/" $2}')
    echo -ne "${COLORS[MAGENTA]}RAM: $mem_usage${COLORS[RESET]}"

    # Network/Torrent stats
    draw_box "TORRENT STATUS" $stats_y $((col_width * 2 + 1)) $((TERM_WIDTH - col_width * 2 - 2)) $stats_height
    tput cup $((stats_y + 1)) $((col_width * 2 + 3))

    if is_transmission_running; then
        local active=$(get_active_count 2>/dev/null || echo "0")
        echo -ne "${COLORS[GREEN]}Active: $active${COLORS[RESET]}"
        tput cup $((stats_y + 2)) $((col_width * 2 + 3))
        local total=$(get_total_count 2>/dev/null || echo "0")
        echo -ne "${COLORS[BLUE]}Total: $total${COLORS[RESET]}"
    else
        echo -ne "${COLORS[RED]}Daemon: OFF${COLORS[RESET]}"
    fi
}

# Main draw function
draw_screen() {
    get_terminal_size

    # Only clear screen on first draw to prevent flickering
    if [ $FIRST_DRAW -eq 1 ]; then
        echo -ne "$CLEAR_SCREEN"
        FIRST_DRAW=0
    fi

    # Position cursor at home and hide it
    echo -ne "$CURSOR_HOME$HIDE_CURSOR"

    # Draw all sections
    draw_header
    draw_torrent_section
    draw_torrent_details
    draw_stats_section
    draw_footer

    # Keep cursor hidden during updates
}

# Handle terminal resize
handle_resize() {
    NEED_REDRAW=1
    FIRST_DRAW=1
}

# Cleanup on exit
cleanup() {
    echo -ne "$SHOW_CURSOR$CLEAR_SCREEN$CURSOR_HOME"
    echo -e "${COLORS[GREEN]}Dashboard stopped. Goodbye!${COLORS[RESET]}"
    stty echo
    RUNNING=0
    exit 0
}

# Handle user input (FIXED: Now properly starts/stops torrents)
handle_input() {
    local key
    read -rsn1 -t 0.1 key

    # Capture escape sequences for arrow keys
    if [[ "$key" == $'\e' ]]; then
        local rest
        read -rsn2 -t 0.1 rest
        key+="$rest"
    fi

    case "$key" in
        q|Q)
            cleanup
            ;;
        r|R)
            NEED_REDRAW=1
            REFRESH_TORRENTS=1
            ;;
        $'\e[A') # Up arrow: move selection up
            if [ $SELECTED_INDEX -gt 0 ]; then
                SELECTED_INDEX=$((SELECTED_INDEX - 1))
                NEED_REDRAW=1
            fi
            ;;
        $'\e[B') # Down arrow: move selection down
            if [ $TORRENT_TOTAL_LINES -gt 0 ] && [ $SELECTED_INDEX -lt $((TORRENT_TOTAL_LINES - 1)) ]; then
                SELECTED_INDEX=$((SELECTED_INDEX + 1))
                NEED_REDRAW=1
            fi
            ;;
        s|S)
            # Start torrent manager
            if ! pgrep -f "torrent_manager.sh" > /dev/null; then
                nohup "$PROJECT_ROOT/lib/torrent_manager.sh" > "$LOG_DIR/nohup.log" 2>&1 &
            fi
            NEED_REDRAW=1
            ;;
        t|T)
            # Stop all torrents
            if is_transmission_running; then
                stop_torrent "all"
            fi
            NEED_REDRAW=1
            ;;
        p|P)
            # Pause all torrents
            if is_transmission_running; then
                stop_torrent "all"
            fi
            NEED_REDRAW=1
            ;;
        u|U)
            # Resume all torrents
            if is_transmission_running; then
                start_torrent "all"
            fi
            NEED_REDRAW=1
            ;;
    esac
}

# Main loop
main() {
    # Setup
    trap cleanup EXIT INT TERM
    trap handle_resize WINCH

    # Disable input echo
    stty -echo

    echo -ne "$HIDE_CURSOR"

    # Initial draw
    draw_screen

    # Main loop
    while [ $RUNNING -eq 1 ]; do
        # Handle resize
        if [ $NEED_REDRAW -eq 1 ]; then
            draw_screen
            NEED_REDRAW=0
            LAST_REFRESH=$(date +%s)
        fi

        # Handle input
        handle_input

        # Auto-refresh every 2 seconds
        sleep 0.1

        # Periodic redraw (only if 2 seconds have passed)
        local current_time=$(date +%s)
        if [ $((current_time - LAST_REFRESH)) -ge 2 ]; then
            REFRESH_TORRENTS=1
            NEED_REDRAW=1
        fi
    done
}

# Run the dashboard
main
