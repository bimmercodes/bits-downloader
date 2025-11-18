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
CONTENT_DIRTY=0
FOOTER_DIRTY=1
SCROLL_OFFSET=0
TORRENT_TOTAL_LINES=0
TORRENT_VIEW_HEIGHT=0
SELECTED_INDEX=0
REFRESH_TORRENTS=1
declare -a TORRENT_CACHE=()
declare -a DETAIL_LINES=()
declare -a WRAPPED_DETAIL_LINES=()
declare -A TORRENT_INFO_CACHE=()
declare -A TORRENT_SIZE_CACHE=()
HEADER_LINE=""

# Layout state
MAIN_Y=1
MAIN_HEIGHT=0
LIST_BOX_X=1
LIST_BOX_WIDTH=0
LIST_BOX_HEIGHT=0
DETAIL_BOX_Y=0
DETAIL_BOX_X=0
DETAIL_BOX_WIDTH=0
DETAIL_BOX_HEIGHT=0

# Focus/scrolling
ACTIVE_PANE="list"   # list | details
DETAIL_SCROLL_OFFSET=0
ORIG_STTY=""

# Trim text to fit a width with ellipsis
trim_text() {
    local text="$1"
    local max_width="$2"
    if [ -z "$max_width" ] || [ "$max_width" -le 3 ]; then
        echo "$text"
        return
    fi
    local length=${#text}
    if [ "$length" -le "$max_width" ]; then
        echo "$text"
    else
        echo "${text:0:$((max_width-3))}..."
    fi
}

# Extract raw byte count from a transmission info line like "(1,234 bytes)"
extract_bytes_from_line() {
    local line="$1"
    if [[ "$line" =~ \(([0-9,]+)[[:space:]]bytes\) ]]; then
        local bytes="${BASH_REMATCH[1]//,/}"
        echo "$bytes"
    fi
}

# Get and cache torrent info by id
get_cached_info() {
    local id="$1"
    local info="${TORRENT_INFO_CACHE[$id]}"
    if [ -z "$info" ]; then
        info="$(get_torrent_info "$id")"
        TORRENT_INFO_CACHE["$id"]="$info"
    fi
    echo "$info"
}

# Compute on-disk size (cached) using location/name from info
compute_ondisk_size() {
    local id="$1"
    local info="$2"
    local cached="${TORRENT_SIZE_CACHE[$id]}"
    [ -n "$cached" ] && { echo "$cached"; return; }

    local name location ondisk="N/A"
    name=$(echo "$info" | awk '/^ *Name:/ {sub(/^[^:]*: */,""); print}')
    location=$(echo "$info" | awk '/^ *Location:/ {sub(/^[^:]*: */,""); print}')

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

    TORRENT_SIZE_CACHE["$id"]="$ondisk"
    echo "$ondisk"
}

# Format a torrent row showing on-disk size instead of "Done"
format_torrent_row() {
    local raw_line="$1"
    local width="$2"
    local provided_info="${3:-}"
    local provided_size="${4:-}"

    local id=$(echo "$raw_line" | awk '{print $1}' | tr -d '*')
    local info="$provided_info"
    if [ -z "$info" ]; then
        info="$(get_cached_info "$id")"
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
    local col_percent_width=7

    local fixed_total=$((col_id_width + col_size_width + col_down_width + col_up_width + col_status_width + col_percent_width + 5))
    local name_width=$((width - fixed_total))
    (( name_width < 5 )) && name_width=5

    local display_name="${name:0:$name_width}"

    printf "%-*s %-*s %-*s %-*s %-*s %-*s %s" \
        "$col_id_width" "$id" \
        "$col_size_width" "$ondisk" \
        "$col_down_width" "${down:-0}" \
        "$col_up_width" "${up:-0}" \
        "$col_status_width" "${status:0:$col_status_width}" \
        "$col_percent_width" "${percent:-N/A}" \
        "$display_name"
}

# Calculate layout to avoid overlaps and stay responsive
compute_layout() {
    local footer_height=2
    local available=$((TERM_HEIGHT - MAIN_Y - footer_height))

    MAIN_HEIGHT=$available
    [ $MAIN_HEIGHT -lt 6 ] && MAIN_HEIGHT=6

    # Ensure we never exceed terminal bounds
    local total_needed=$((MAIN_Y + MAIN_HEIGHT + footer_height))
    if [ $total_needed -gt $TERM_HEIGHT ]; then
        MAIN_HEIGHT=$((TERM_HEIGHT - MAIN_Y - footer_height))
        [ $MAIN_HEIGHT -lt 3 ] && MAIN_HEIGHT=3
    fi

    # Stack list above details, both full width
    LIST_BOX_X=1
    DETAIL_BOX_X=1
    local vertical_spacing=1
    LIST_BOX_WIDTH=$((TERM_WIDTH - 2))
    [ $LIST_BOX_WIDTH -lt 18 ] && LIST_BOX_WIDTH=18
    DETAIL_BOX_WIDTH=$LIST_BOX_WIDTH

    LIST_BOX_HEIGHT=$((MAIN_HEIGHT * 2 / 3))
    [ $LIST_BOX_HEIGHT -lt 6 ] && LIST_BOX_HEIGHT=6
    DETAIL_BOX_HEIGHT=$((MAIN_HEIGHT - LIST_BOX_HEIGHT - vertical_spacing))
    [ $DETAIL_BOX_HEIGHT -lt 3 ] && DETAIL_BOX_HEIGHT=3

    # Ensure stacked boxes fit within MAIN_HEIGHT
    if [ $((LIST_BOX_HEIGHT + DETAIL_BOX_HEIGHT + vertical_spacing)) -gt $MAIN_HEIGHT ]; then
        DETAIL_BOX_HEIGHT=$((MAIN_HEIGHT - vertical_spacing - LIST_BOX_HEIGHT))
        [ $DETAIL_BOX_HEIGHT -lt 3 ] && DETAIL_BOX_HEIGHT=3
        if [ $((LIST_BOX_HEIGHT + DETAIL_BOX_HEIGHT + vertical_spacing)) -gt $MAIN_HEIGHT ]; then
            LIST_BOX_HEIGHT=$((MAIN_HEIGHT - vertical_spacing - DETAIL_BOX_HEIGHT))
            [ $LIST_BOX_HEIGHT -lt 3 ] && LIST_BOX_HEIGHT=3
        fi
    fi

    DETAIL_BOX_Y=$((MAIN_Y + LIST_BOX_HEIGHT + vertical_spacing))
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

# Build consolidated status text for the header
build_header_status() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local dl_count dl_size cpu_load mem_usage active total daemon_status
    if [ -d "$DOWNLOAD_DIR" ]; then
        dl_count=$(find "$DOWNLOAD_DIR" -type f 2>/dev/null | wc -l)
        dl_size=$(du -sh "$DOWNLOAD_DIR" 2>/dev/null | cut -f1)
    else
        dl_count="0"
        dl_size="0"
    fi
    cpu_load=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d, -f1 | xargs)
    mem_usage=$(free -h 2>/dev/null | awk '/^Mem:/ {print $3 "/" $2}')
    if is_transmission_running; then
        daemon_status="RUN"
        active=$(get_active_count 2>/dev/null || echo "0")
        total=$(get_total_count 2>/dev/null || echo "0")
    else
        daemon_status="OFF"
        active="0"
        total="0"
    fi

    echo "Time: $timestamp | Torrents: $active/$total ($daemon_status) | CPU: ${cpu_load:-N/A} | RAM: ${mem_usage:-N/A} | Downloads: ${dl_count:-0} files ${dl_size:-0}"
}

# Draw header with only the dynamic status line (no banner/logo)
draw_header() {
    local status_text
    status_text="$(build_header_status)"
    local max_status_width=$((TERM_WIDTH - 2))
    status_text="$(trim_text "$status_text" "$max_status_width")"
    local status_pos=$(( TERM_WIDTH - ${#status_text} - 1 ))
    [ $status_pos -lt 0 ] && status_pos=0

    tput cup 0 0
    echo -ne "${COLORS[BG_BLUE]}${COLORS[CYAN]}${COLORS[BOLD]}"
    printf "%${TERM_WIDTH}s" " "
    tput cup 0 $status_pos
    echo -ne "$status_text${COLORS[RESET]}"

    # Separator line
    tput cup 1 0
    echo -ne "${COLORS[BLUE]}"
    draw_line "=" $TERM_WIDTH
    echo -ne "${COLORS[RESET]}"
}

# Update only the status line (row 0) without redrawing the whole screen
draw_header_status_line() {
    local status_text
    status_text="$(build_header_status)"
    local max_status_width=$((TERM_WIDTH - 2))
    status_text="$(trim_text "$status_text" "$max_status_width")"
    local status_pos=$(( TERM_WIDTH - ${#status_text} - 1 ))
    [ $status_pos -lt 0 ] && status_pos=0

    tput cup 0 0
    echo -ne "${COLORS[BG_BLUE]}${COLORS[CYAN]}${COLORS[BOLD]}"
    printf "%${TERM_WIDTH}s" " "
    tput cup 0 $status_pos
    echo -ne "$status_text${COLORS[RESET]}"
} 

# Draw footer
draw_footer() {
    local footer_y=$((TERM_HEIGHT - 2))

    # Footer content
    tput cup $footer_y 0
    echo -ne "${COLORS[BG_BLACK]}${COLORS[CYAN]}"
    printf "%${TERM_WIDTH}s" " "

    local footer_text="Arrows: Move/Scroll  Tab: Switch Focus  R: Refresh  B: Boost  D: Delete  Q: Quit"
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

    local signature="Made with ♥ by BIMMERCODES ⧉ github.com/bimmercodes"
    tput cup $((footer_y + 1)) $((TERM_WIDTH - ${#signature} - 1))
    echo -n "$signature"
    echo -ne "${COLORS[RESET]}"
}

# Redraw only the sections with frequently changing data to avoid full-screen refresh flicker
refresh_dynamic_sections() {
    draw_header_status_line
    draw_torrent_section
    draw_torrent_details
    if [ $FOOTER_DIRTY -eq 1 ]; then
        draw_footer
        FOOTER_DIRTY=0
    fi
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
    local info="${2:-}"
    DETAIL_LINES=()
    WRAPPED_DETAIL_LINES=()

    if [ -z "$info" ]; then
        info="$(get_cached_info "$id_field")"
    fi
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

# Wrap detail lines to fit a given width
wrap_detail_lines() {
    local width="$1"
    WRAPPED_DETAIL_LINES=()

    for line in "${DETAIL_LINES[@]}"; do
        local remaining="$line"
        if [ ${#remaining} -le "$width" ]; then
            WRAPPED_DETAIL_LINES+=("$remaining")
            continue
        fi
        while [ -n "$remaining" ]; do
            local segment="${remaining:0:$width}"
            WRAPPED_DETAIL_LINES+=("$segment")
            remaining="${remaining:$width}"
        done
    done
}

# Ensure detail scroll offset stays within bounds
clamp_detail_scroll() {
    local visible_height=$((DETAIL_BOX_HEIGHT - 2))
    local max_offset=$(( ${#WRAPPED_DETAIL_LINES[@]} - visible_height ))
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
        HEADER_LINE=$(printf "%-4s %-11s %-10s %-10s %-10s %-7s %s" \
            "ID" "OnDisk" "Down" "Up" "Status" "Pct" "Name")

        TORRENT_CACHE=()
        TORRENT_INFO_CACHE=()
        TORRENT_SIZE_CACHE=()
        for ((i=1; i<${#raw_torrents[@]}; i++)); do
            line="${raw_torrents[$i]}"
            [[ "$line" =~ ^Sum: ]] && continue
            TORRENT_CACHE+=("$line")
            local id=$(echo "$line" | awk '{print $1}' | tr -d '*')
            local info="$(get_cached_info "$id")"
            TORRENT_INFO_CACHE["$id"]="$info"
            TORRENT_SIZE_CACHE["$id"]="$(compute_ondisk_size "$id" "$info")"
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
            local info="${TORRENT_INFO_CACHE[$id]}"
            [ -z "$info" ] && info="$(get_cached_info "$id")"
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
            display_line=$(format_torrent_row "$line" "$content_width" "$info" "${TORRENT_SIZE_CACHE[$id]}")
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
    local box_y=$DETAIL_BOX_Y
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

    local cached_info="${TORRENT_INFO_CACHE[$id_field]}"
    if [ -z "$cached_info" ]; then
        cached_info="$(get_cached_info "$id_field")"
    fi

    build_detail_lines "$id_field" "$cached_info"
    wrap_detail_lines "$content_width"

    clamp_detail_scroll
    local total_lines=${#WRAPPED_DETAIL_LINES[@]}

    for ((i=0; i<content_height; i++)); do
        local idx=$((i + DETAIL_SCROLL_OFFSET))
        tput cup $((content_y + i)) $content_x

        if [ $idx -lt $total_lines ]; then
            local line="${WRAPPED_DETAIL_LINES[$idx]}"
            printf "%-${content_width}s" "$line"
        else
            printf "%-${content_width}s" " "
        fi
    done
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

    # With non-canonical mode enabled globally, this read would otherwise return immediately.
    # Wait briefly to allow the user to answer the prompt.
    local choice
    read -rsn1 -t 5 choice || choice=""

    # Clear the prompt line immediately after input
    tput cup $prompt_y 0
    printf "%-${TERM_WIDTH}s" " "

    if [[ "$choice" =~ [yY] ]]; then
        remove_torrent "$id_field"
        REFRESH_TORRENTS=1
    fi

    CONTENT_DIRTY=1
    FOOTER_DIRTY=1
}

# Force start and reannounce the selected torrent to try to speed it up
boost_selected_torrent() {
    if [ $TORRENT_TOTAL_LINES -eq 0 ]; then
        return
    fi

    if ! is_transmission_running; then
        return
    fi

    local selected_line="${TORRENT_CACHE[$SELECTED_INDEX]}"
    local id_field=$(echo "$selected_line" | awk '{print $1}')

    force_start_torrent "$id_field"
    REFRESH_TORRENTS=1
    CONTENT_DIRTY=1
    FOOTER_DIRTY=1
}

# Handle user input (FIXED: Now properly starts/stops torrents)
handle_input() {
    local key=""
    read -rsn1 -t 0.1 key || key=""

    # Capture escape sequences for arrow keys
    if [[ "$key" == $'\e' ]]; then
        local rest
        read -rsn2 -t 0.1 rest
        key+="$rest"
    fi

    # Nothing pressed
    [ -z "$key" ] && return

    case "$key" in
        q|Q)
            cleanup
            ;;
        r|R)
            REFRESH_TORRENTS=1
            CONTENT_DIRTY=1
            FOOTER_DIRTY=1
            ;;
        $'\t'|$'\e[Z') # Tab or reverse-tab
            if [ "$ACTIVE_PANE" = "list" ]; then
                ACTIVE_PANE="details"
                DETAIL_SCROLL_OFFSET=0
            else
                ACTIVE_PANE="list"
            fi
            CONTENT_DIRTY=1
            NEED_REDRAW=1  # ensure box titles/highlights update immediately
            FOOTER_DIRTY=1
            ;;
        $'\e[A') # Up arrow
            if [ "$ACTIVE_PANE" = "list" ]; then
                if [ $SELECTED_INDEX -gt 0 ]; then
                    SELECTED_INDEX=$((SELECTED_INDEX - 1))
                    DETAIL_SCROLL_OFFSET=0
                    CONTENT_DIRTY=1
                    FOOTER_DIRTY=1
                fi
            else
                DETAIL_SCROLL_OFFSET=$((DETAIL_SCROLL_OFFSET - 1))
                clamp_detail_scroll
                CONTENT_DIRTY=1
                FOOTER_DIRTY=1
            fi
            ;;
        $'\e[B') # Down arrow
            if [ "$ACTIVE_PANE" = "list" ]; then
                if [ $TORRENT_TOTAL_LINES -gt 0 ] && [ $SELECTED_INDEX -lt $((TORRENT_TOTAL_LINES - 1)) ]; then
                    SELECTED_INDEX=$((SELECTED_INDEX + 1))
                    DETAIL_SCROLL_OFFSET=0
                    CONTENT_DIRTY=1
                    FOOTER_DIRTY=1
                fi
            else
                DETAIL_SCROLL_OFFSET=$((DETAIL_SCROLL_OFFSET + 1))
                clamp_detail_scroll
                CONTENT_DIRTY=1
                FOOTER_DIRTY=1
            fi
            ;;
        s|S)
            # Start torrent manager
            if ! pgrep -f "torrent_manager.sh" > /dev/null; then
                nohup "$PROJECT_ROOT/lib/torrent_manager.sh" > "$LOG_DIR/nohup.log" 2>&1 &
            fi
            REFRESH_TORRENTS=1
            CONTENT_DIRTY=1
            FOOTER_DIRTY=1
            ;;
        t|T)
            # Stop all torrents
            if is_transmission_running; then
                stop_torrent "all"
            fi
            REFRESH_TORRENTS=1
            CONTENT_DIRTY=1
            FOOTER_DIRTY=1
            ;;
        p|P)
            # Pause all torrents
            if is_transmission_running; then
                stop_torrent "all"
            fi
            REFRESH_TORRENTS=1
            CONTENT_DIRTY=1
            FOOTER_DIRTY=1
            ;;
        u|U)
            # Resume all torrents
            if is_transmission_running; then
                start_torrent "all"
            fi
            REFRESH_TORRENTS=1
            CONTENT_DIRTY=1
            FOOTER_DIRTY=1
            ;;
        d|D)
            delete_selected_torrent
            ;;
        b|B)
            boost_selected_torrent
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
        # Handle resize or layout changes
        if [ $NEED_REDRAW -eq 1 ]; then
            draw_screen
            NEED_REDRAW=0
            CONTENT_DIRTY=0
            LAST_REFRESH=$(date +%s)
            continue
        fi

        # Handle input (may mark CONTENT_DIRTY/REFRESH_TORRENTS)
        handle_input

        local current_time=$(date +%s)

        # Periodic data refresh without full redraw
        if [ $((current_time - LAST_REFRESH)) -ge 2 ]; then
            REFRESH_TORRENTS=1
            CONTENT_DIRTY=1
            FOOTER_DIRTY=1
        fi

        if [ $CONTENT_DIRTY -eq 1 ]; then
            refresh_dynamic_sections
            CONTENT_DIRTY=0
            LAST_REFRESH=$current_time
        fi

        sleep 0.1
    done
}

# Run the dashboard
main
