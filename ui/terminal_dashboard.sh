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
declare -a DETAIL_LINES=()
HEADER_LINE=""

# Layout state
MAIN_Y=3
MAIN_HEIGHT=0
STATS_Y=0
STATS_HEIGHT=4
LIST_BOX_X=1
LIST_BOX_WIDTH=0
LIST_BOX_HEIGHT=0
DETAIL_BOX_X=0
DETAIL_BOX_WIDTH=0
DETAIL_BOX_HEIGHT=0

# Focus/scrolling
ACTIVE_PANE="list"   # list | details
DETAIL_SCROLL_OFFSET=0
ORIG_STTY=""

# Extract raw byte count from a transmission info line like "(1,234 bytes)"
extract_bytes_from_line() {
    local line="$1"
    if [[ "$line" =~ \(([0-9,]+)[[:space:]]bytes\) ]]; then
        local bytes="${BASH_REMATCH[1]//,/}"
        echo "$bytes"
    fi
}

# Format a torrent row showing on-disk size instead of "Done"
format_torrent_row() {
    local raw_line="$1"
    local width="$2"
    local provided_info="${3:-}"

    local id=$(echo "$raw_line" | awk '{print $1}' | tr -d '*')
    local info="$provided_info"
    if [ -z "$info" ]; then
        info="$(get_torrent_info "$id")"
    fi
    if [ -z "$info" ]; then
        printf "%-${width}s" "N/A"
        return
    fi

    local name status down up location percent
    name=$(echo "$info" | awk '/^ *Name:/ {sub(/^[^:]*: */,""); print}')
    status=$(echo "$info" | awk '/^ *State:/ {sub(/^[^:]*: */,""); print}')
    down=$(echo "$info" | awk '/^ *Download Speed:/ {print $3, $4}')
    up=$(echo "$info" | awk '/^ *Upload Speed:/ {print $3, $4}')
    location=$(echo "$info" | awk '/^ *Location:/ {sub(/^[^:]*: */,""); print}')
    percent=$(echo "$info" | awk '/^ *Percent Done:/ {print $3}')

    # Compute on-disk size using du; fall back to "Have" bytes
    local ondisk="N/A"
    if [ -n "$location" ]; then
        local target="$location"
        if [ -n "$name" ] && [ -e "$location/.incomplete/$name" ]; then
            target="$location/.incomplete/$name"
        elif [ -n "$name" ] && [ -e "$location/$name" ]; then
            target="$location/$name"
        fi
        local size_bytes=$(du -sb "$target" 2>/dev/null | awk '{print $1}')
        if [ -n "$size_bytes" ]; then
            if command -v numfmt >/dev/null 2>&1; then
                ondisk=$(numfmt --to=iec-i "$size_bytes")
            else
                ondisk=$(format_bytes "$size_bytes")
            fi
        fi
    fi
    if [ "$ondisk" = "N/A" ]; then
        local have_bytes=$(extract_bytes_from_line "$(echo "$info" | grep "^ *Have:")")
        if [ -n "$have_bytes" ]; then
            if command -v numfmt >/dev/null 2>&1; then
                ondisk=$(numfmt --to=iec-i "$have_bytes")
            else
                ondisk=$(format_bytes "$have_bytes")
            fi
        fi
    fi

    # Build formatted row
    local col_id_width=4
    local col_size_width=11
    local col_down_width=10
    local col_up_width=10
    local col_status_width=10
    local name_width=$((width - col_id_width - col_size_width - col_down_width - col_up_width - col_status_width - 5))
    (( name_width < 5 )) && name_width=5

    local display_name="${name:0:$name_width}"

    printf "%-*s %-*s %-*s %-*s %-*s %s" \
        "$col_id_width" "$id" \
        "$col_size_width" "$ondisk" \
        "$col_down_width" "${down:-0}" \
        "$col_up_width" "${up:-0}" \
        "$col_status_width" "${status:0:$col_status_width}" \
        "$display_name"
}

# Calculate layout to avoid overlaps and stay responsive
compute_layout() {
    local footer_height=2
    local available=$((TERM_HEIGHT - MAIN_Y - footer_height))

    # Adapt stats height based on available space
    if [ $available -lt 8 ]; then
        STATS_HEIGHT=3
    elif [ $available -lt 12 ]; then
        STATS_HEIGHT=3
    else
        STATS_HEIGHT=4
    fi

    MAIN_HEIGHT=$((available - STATS_HEIGHT))
    [ $MAIN_HEIGHT -lt 6 ] && MAIN_HEIGHT=6

    # Ensure we never exceed terminal bounds
    local total_needed=$((MAIN_Y + MAIN_HEIGHT + STATS_HEIGHT + footer_height))
    if [ $total_needed -gt $TERM_HEIGHT ]; then
        MAIN_HEIGHT=$((TERM_HEIGHT - MAIN_Y - STATS_HEIGHT - footer_height))
        [ $MAIN_HEIGHT -lt 3 ] && MAIN_HEIGHT=3
    fi

    STATS_Y=$((MAIN_Y + MAIN_HEIGHT))

    LIST_BOX_X=1
    local spacing=1
    LIST_BOX_WIDTH=$(( (TERM_WIDTH - 3) * 3 / 5 ))
    (( LIST_BOX_WIDTH < 20 )) && LIST_BOX_WIDTH=$((TERM_WIDTH/2 - 2))
    (( LIST_BOX_WIDTH < 18 )) && LIST_BOX_WIDTH=18

    DETAIL_BOX_X=$((LIST_BOX_X + LIST_BOX_WIDTH + spacing))
    DETAIL_BOX_WIDTH=$((TERM_WIDTH - DETAIL_BOX_X - 1))

    if [ $DETAIL_BOX_WIDTH -lt 24 ]; then
        DETAIL_BOX_WIDTH=$((TERM_WIDTH - LIST_BOX_X - 3))
        [ $DETAIL_BOX_WIDTH -lt 18 ] && DETAIL_BOX_WIDTH=18
        LIST_BOX_WIDTH=$((TERM_WIDTH - DETAIL_BOX_WIDTH - spacing - 1))
        [ $LIST_BOX_WIDTH -lt 18 ] && LIST_BOX_WIDTH=18
        DETAIL_BOX_X=$((LIST_BOX_X + LIST_BOX_WIDTH + spacing))
    fi

    LIST_BOX_HEIGHT=$MAIN_HEIGHT
    DETAIL_BOX_HEIGHT=$MAIN_HEIGHT
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

    local footer_text="Arrows: Move/Scroll  Tab: Switch Focus  R: Refresh  D: Delete  Q: Quit"
    local footer_pos=$(( (TERM_WIDTH - ${#footer_text}) / 2 ))
    tput cup $footer_y $footer_pos
    echo -n "$footer_text"

    # Status bar
    tput cup $((footer_y + 1)) 0
    printf "%${TERM_WIDTH}s" " "
    tput cup $((footer_y + 1)) 0
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local focus_text="Focus: ${ACTIVE_PANE^^}"

    # Show transmission status
    if is_transmission_running; then
        echo -ne "${COLORS[GREEN]}"
        echo -n "> Status: RUNNING"
    else
        echo -ne "${COLORS[RED]}"
        echo -n "> Status: STOPPED"
    fi

    echo -ne "${COLORS[RESET]}  ${COLORS[CYAN]}$focus_text${COLORS[RESET]}"

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

# Build detail lines for the selected torrent (used for scrolling)
build_detail_lines() {
    local id_field="$1"
    DETAIL_LINES=()

    local info
    info="$(get_torrent_info "$id_field")"
    if [ -z "$info" ]; then
        DETAIL_LINES+=("Unable to load torrent details.")
        return
    fi

    local name eta uploaded downloaded size downloaded_total peers availability location status percent ratio remaining

    name=$(echo "$info" | awk '/^ *Name:/ {sub(/^[^:]*: */,""); print}')
    eta=$(echo "$info" | awk '/^ *ETA:/ {sub(/^[^:]*: */,""); print}')
    uploaded=$(echo "$info" | awk '/^ *Upload Speed:/ {print $3, $4}')
    downloaded=$(echo "$info" | awk '/^ *Download Speed:/ {print $3, $4}')
    size=$(echo "$info" | awk '/^ *Total size:/ {print $3, $4}')
    downloaded_total=$(echo "$info" | awk '/^ *Have:/ {sub(/^[^:]*: */,""); print}')
    peers=$(echo "$info" | awk '/^ *Peers:/ {print $2}')
    availability=$(echo "$info" | awk '/^ *Availability:/ {print $2}')
    location=$(echo "$info" | awk '/^ *Location:/ {sub(/^[^:]*: */,""); print}')
    status=$(echo "$info" | awk '/^ *State:/ {sub(/^[^:]*: */,""); print}')
    percent=$(echo "$info" | awk '/^ *Percent Done:/ {print $3}')
    ratio=$(echo "$info" | awk '/^ *Ratio:/ {print $2}')

    local total_bytes=$(extract_bytes_from_line "$(echo "$info" | grep "^ *Total size:")")
    local downloaded_bytes=$(extract_bytes_from_line "$(echo "$info" | grep "^ *Have:")")
    local remaining_bytes=""

    if [[ -n "$total_bytes" && -n "$downloaded_bytes" ]]; then
        remaining_bytes=$((total_bytes - downloaded_bytes))
        if command -v numfmt >/dev/null 2>&1; then
            remaining=$(numfmt --to=iec-i --suffix=B "$remaining_bytes")
        else
            remaining="${remaining_bytes} B"
        fi
    else
        remaining="N/A"
    fi

    DETAIL_LINES+=("ID: $id_field   Status: ${status:-N/A}   Percent: ${percent:-N/A}")
    DETAIL_LINES+=("Name: ${name:-N/A}")
    DETAIL_LINES+=("Progress: ${downloaded_total:-N/A} / ${size:-N/A}   Remaining: ${remaining:-N/A}")
    DETAIL_LINES+=("ETA: ${eta:-N/A}   Speeds: ↓ ${downloaded:-N/A} ↑ ${uploaded:-N/A}")
    DETAIL_LINES+=("Peers: ${peers:-N/A}   Availability: ${availability:-N/A}   Ratio: ${ratio:-N/A}")
    DETAIL_LINES+=("Location: ${location:-N/A}")
    DETAIL_LINES+=("Files:")

    local files=$(get_torrent_files "$id_field")
    local file_lines=$(echo "$files" | tail -n +2)
    if [ -z "$file_lines" ]; then
        DETAIL_LINES+=("  No files available.")
    else
        while IFS= read -r file_line; do
            DETAIL_LINES+=("  ${file_line}")
        done <<< "$file_lines"
    fi
}

# Ensure detail scroll offset stays within bounds
clamp_detail_scroll() {
    local visible_height=$((DETAIL_BOX_HEIGHT - 2))
    local max_offset=$(( ${#DETAIL_LINES[@]} - visible_height ))
    (( max_offset < 0 )) && max_offset=0

    (( DETAIL_SCROLL_OFFSET < 0 )) && DETAIL_SCROLL_OFFSET=0
    (( DETAIL_SCROLL_OFFSET > max_offset )) && DETAIL_SCROLL_OFFSET=$max_offset
}

# Draw torrent list
draw_torrent_section() {
    local box_y=$MAIN_Y
    local box_x=$LIST_BOX_X
    local box_width=$LIST_BOX_WIDTH
    local box_height=$LIST_BOX_HEIGHT
    local title="ACTIVE TORRENTS"
    [[ "$ACTIVE_PANE" == "list" ]] && title+=" [ACTIVE]"

    draw_box "$title" $box_y $box_x $box_width $box_height

    # Content area
    local content_y=$((box_y + 1))
    local content_x=$((box_x + 2))
    local content_width=$((box_width - 4))
    local content_height=$((box_height - 2))

    TORRENT_VIEW_HEIGHT=$content_height

    # Refresh torrent data only when needed (avoid lag on scroll)
    if [ $REFRESH_TORRENTS -eq 1 ]; then
        mapfile -t raw_torrents < <(get_torrent_stats)
        HEADER_LINE=$(printf "%-4s %-11s %-10s %-10s %-10s %s" "ID" "OnDisk" "Down" "Up" "Status" "Name")

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
            local id=$(echo "$line" | awk '{print $1}' | tr -d '*')
            local info="$(get_torrent_info "$id")"
            local status=$(echo "$info" | awk '/^ *State:/ {sub(/^[^:]*: */,""); print}')
            local percent=$(echo "$info" | awk '/^ *Percent Done:/ {print $3}')

            # Colorize based on status/percent
            if [[ "$percent" == "100%" ]] || [[ "$status" =~ [Ss]eeding ]]; then
                echo -ne "${COLORS[GREEN]}"
            elif [[ "$status" =~ [Dd]ownloading ]] || [[ "$status" =~ "Up & Down" ]]; then
                echo -ne "${COLORS[YELLOW]}"
            elif [[ "$status" =~ [Ss]topped ]] || [[ "$status" =~ [Ii]dle ]]; then
                echo -ne "${COLORS[RED]}"
            else
                echo -ne "${COLORS[CYAN]}"
            fi

            # Highlight selected row
            if [ $idx -eq $SELECTED_INDEX ]; then
                echo -ne "${COLORS[BG_CYAN]}${COLORS[BLUE]}"
            fi

            local display_line
            display_line=$(format_torrent_row "$line" "$content_width" "$info")
            printf "%-${content_width}s" "$display_line"
            echo -ne "${COLORS[RESET]}"
        else
            printf "%${content_width}s" " "
        fi
    done
}

# Draw torrent details for selected torrent (scrollable)
draw_torrent_details() {
    local box_x=$DETAIL_BOX_X
    local box_y=$MAIN_Y
    local box_width=$DETAIL_BOX_WIDTH
    local box_height=$DETAIL_BOX_HEIGHT
    local title="TORRENT DETAILS"
    [[ "$ACTIVE_PANE" == "details" ]] && title+=" [ACTIVE]"

    draw_box "$title" $box_y $box_x $box_width $box_height

    local content_y=$((box_y + 1))
    local content_x=$((box_x + 2))
    local content_width=$((box_width - 4))
    local content_height=$((box_height - 2))

    if [ $TORRENT_TOTAL_LINES -eq 0 ]; then
        tput cup $content_y $content_x
        echo -ne "${COLORS[RED]}No torrents to display${COLORS[RESET]}"
        return
    fi

    local selected_line="${TORRENT_CACHE[$SELECTED_INDEX]}"
    local id_field=$(echo "$selected_line" | awk '{print $1}')

    build_detail_lines "$id_field"

    clamp_detail_scroll
    local total_lines=${#DETAIL_LINES[@]}

    for ((i=0; i<content_height; i++)); do
        local idx=$((i + DETAIL_SCROLL_OFFSET))
        tput cup $((content_y + i)) $content_x

        if [ $idx -lt $total_lines ]; then
            local line="${DETAIL_LINES[$idx]}"
            printf "%-${content_width}s" "${line:0:$content_width}"
        else
            printf "%-${content_width}s" " "
        fi
    done
}

# Draw stats section
draw_stats_section() {
    local stats_y=$STATS_Y
    local stats_height=$STATS_HEIGHT
    local inner_height=$((stats_height - 2))

    # Three columns for stats
    local col_width=$((TERM_WIDTH / 3))
    (( col_width < 12 )) && col_width=12

    # Download stats
    draw_box "DOWNLOADS" $stats_y 1 $col_width $stats_height
    if [ $inner_height -ge 1 ]; then
        tput cup $((stats_y + 1)) 3
        if [ -d "$DOWNLOAD_DIR" ]; then
            local dl_count=$(find "$DOWNLOAD_DIR" -type f 2>/dev/null | wc -l)
            echo -ne "${COLORS[GREEN]}Files: $dl_count${COLORS[RESET]}"
        else
            echo -ne "${COLORS[RED]}Dir not found${COLORS[RESET]}"
        fi
    fi
    if [ $inner_height -ge 2 ]; then
        tput cup $((stats_y + 2)) 3
        local dl_size=$(du -sh "$DOWNLOAD_DIR" 2>/dev/null | cut -f1)
        echo -ne "${COLORS[CYAN]}Size: ${dl_size:-0}${COLORS[RESET]}"
    fi

    # System stats
    draw_box "SYSTEM" $stats_y $((col_width + 1)) $col_width $stats_height
    if [ $inner_height -ge 1 ]; then
        tput cup $((stats_y + 1)) $((col_width + 3))
        local cpu_load=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d, -f1 | xargs)
        echo -ne "${COLORS[YELLOW]}Load: $cpu_load${COLORS[RESET]}"
    fi
    if [ $inner_height -ge 2 ]; then
        tput cup $((stats_y + 2)) $((col_width + 3))
        local mem_usage=$(free -h 2>/dev/null | awk '/^Mem:/ {print $3 "/" $2}')
        echo -ne "${COLORS[MAGENTA]}RAM: $mem_usage${COLORS[RESET]}"
    fi

    # Network/Torrent stats
    local status_width=$((TERM_WIDTH - col_width * 2 - 2))
    (( status_width < 12 )) && status_width=12
    draw_box "TORRENT STATUS" $stats_y $((col_width * 2 + 1)) $status_width $stats_height
    if [ $inner_height -ge 1 ]; then
        tput cup $((stats_y + 1)) $((col_width * 2 + 3))
        if is_transmission_running; then
            local active=$(get_active_count 2>/dev/null || echo "0")
            echo -ne "${COLORS[GREEN]}Active: $active${COLORS[RESET]}"
        else
            echo -ne "${COLORS[RED]}Daemon: OFF${COLORS[RESET]}"
        fi
    fi
    if [ $inner_height -ge 2 ]; then
        tput cup $((stats_y + 2)) $((col_width * 2 + 3))
        local total=$(get_total_count 2>/dev/null || echo "0")
        echo -ne "${COLORS[BLUE]}Total: $total${COLORS[RESET]}"
    fi
}

# Main draw function
draw_screen() {
    get_terminal_size
    compute_layout

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
    if [ -n "$ORIG_STTY" ]; then
        stty "$ORIG_STTY" 2>/dev/null || stty echo
    else
        stty echo
    fi
    RUNNING=0
    exit 0
}

# Prompt and remove the currently selected torrent
delete_selected_torrent() {
    # Nothing to delete
    if [ $TORRENT_TOTAL_LINES -eq 0 ]; then
        return
    fi

    local selected_line="${TORRENT_CACHE[$SELECTED_INDEX]}"
    local id_field=$(echo "$selected_line" | awk '{print $1}')
    local torrent_name=$(get_torrent_field "$id_field" "name")

    # Ask for confirmation on the status line
    local prompt_y=$((TERM_HEIGHT - 1))
    local name_width=$((TERM_WIDTH - 32))
    (( name_width < 0 )) && name_width=0

    tput cup $prompt_y 0
    echo -ne "${COLORS[RESET]}"
    printf "%-${TERM_WIDTH}s" " Delete torrent #$id_field (${torrent_name:0:$name_width})? [y/N] "

    local choice
    read -rsn1 choice

    # Clear the prompt line immediately after input
    tput cup $prompt_y 0
    printf "%-${TERM_WIDTH}s" " "

    if [[ "$choice" =~ [yY] ]]; then
        remove_torrent "$id_field"
        REFRESH_TORRENTS=1
    fi

    NEED_REDRAW=1
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
        $'\t')
            if [ "$ACTIVE_PANE" = "list" ]; then
                ACTIVE_PANE="details"
            else
                ACTIVE_PANE="list"
            fi
            NEED_REDRAW=1
            ;;
        $'\e[A') # Up arrow
            if [ "$ACTIVE_PANE" = "list" ]; then
                if [ $SELECTED_INDEX -gt 0 ]; then
                    SELECTED_INDEX=$((SELECTED_INDEX - 1))
                    DETAIL_SCROLL_OFFSET=0
                    NEED_REDRAW=1
                fi
            else
                DETAIL_SCROLL_OFFSET=$((DETAIL_SCROLL_OFFSET - 1))
                clamp_detail_scroll
                NEED_REDRAW=1
            fi
            ;;
        $'\e[B') # Down arrow
            if [ "$ACTIVE_PANE" = "list" ]; then
                if [ $TORRENT_TOTAL_LINES -gt 0 ] && [ $SELECTED_INDEX -lt $((TORRENT_TOTAL_LINES - 1)) ]; then
                    SELECTED_INDEX=$((SELECTED_INDEX + 1))
                    DETAIL_SCROLL_OFFSET=0
                    NEED_REDRAW=1
                fi
            else
                DETAIL_SCROLL_OFFSET=$((DETAIL_SCROLL_OFFSET + 1))
                clamp_detail_scroll
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
        d|D)
            delete_selected_torrent
            ;;
    esac
}

# Main loop
main() {
    # Setup
    trap cleanup EXIT INT TERM
    trap handle_resize WINCH

    # Disable input echo
    ORIG_STTY=$(stty -g)
    stty -echo -icanon time 0 min 0

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
