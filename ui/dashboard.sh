#!/bin/bash

# BITS Downloader - Full-Screen Interactive Dashboard

UI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$UI_DIR/.." && pwd)"

source "$PROJECT_ROOT/lib/config.sh"
source "$PROJECT_ROOT/lib/utils.sh"
source "$PROJECT_ROOT/lib/transmission_api.sh"

# Check dependencies
if ! command -v dialog &> /dev/null; then
    echo "ERROR: 'dialog' is not installed."
    echo "Install: sudo apt-get install dialog"
    exit 1
fi

# ============================================================================
# TERMINAL SETUP
# ============================================================================

DIALOG_TEMP=$(mktemp)
trap "cleanup" EXIT INT TERM

cleanup() {
    rm -f "$DIALOG_TEMP"
    tput cnorm
    clear
}

# Enable mouse support in dialog
export DIALOGRC=""

# ============================================================================
# DASHBOARD STATE
# ============================================================================

SELECTED_ROW=0
RUNNING=1
AUTO_REFRESH=1
REFRESH_INTERVAL=2

# ============================================================================
# UI HELPERS
# ============================================================================

get_terminal_size() {
    TERM_HEIGHT=$(tput lines)
    TERM_WIDTH=$(tput cols)
}

# ============================================================================
# TORRENT DATA
# ============================================================================

declare -a TORRENT_IDS
declare -A TORRENT_DATA

refresh_torrent_data() {
    TORRENT_IDS=()
    TORRENT_DATA=()

    if ! is_transmission_running; then
        return 1
    fi

    local list=$(get_torrent_list 2>/dev/null)
    if [ -z "$list" ]; then
        return 1
    fi

    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*ID ]] || [[ "$line" =~ ^Sum: ]]; then
            continue
        fi

        local id=$(echo "$line" | awk '{print $1}')
        if ! [[ "$id" =~ ^[0-9]+$ ]]; then
            continue
        fi

        TORRENT_IDS+=("$id")

        local done=$(echo "$line" | awk '{print $(NF-4)}')
        local status=$(echo "$line" | awk '{print $NF}')
        local name=$(echo "$line" | awk '{for(i=10;i<=NF-5;i++) printf "%s ", $i}' | sed 's/[[:space:]]*$//')
        local size=$(echo "$line" | awk '{print $(NF-3)" "$(NF-2)}')

        TORRENT_DATA["${id}_name"]="$name"
        TORRENT_DATA["${id}_done"]="$done"
        TORRENT_DATA["${id}_status"]="$status"
        TORRENT_DATA["${id}_size"]="$size"
    done <<< "$list"

    return 0
}

# ============================================================================
# ACTIONS
# ============================================================================

action_add_torrent() {
    if ! is_transmission_running; then
        dialog --title "Error" --msgbox "Transmission daemon is not running!" 7 50
        return
    fi

    dialog --title "Add Torrent" \
           --inputbox "Enter magnet link, URL, or file path:" 10 70 \
           2> "$DIALOG_TEMP"

    if [ $? -ne 0 ]; then
        return
    fi

    local input=$(cat "$DIALOG_TEMP")
    if [ -z "$input" ]; then
        return
    fi

    local result=$(add_torrent "$input" "$DOWNLOAD_DIR" 2>&1)

    if [ $? -eq 0 ]; then
        dialog --title "Success" --msgbox "Torrent added!\n\n$result" 10 60
        refresh_torrent_data
        SELECTED_ROW=0
    else
        dialog --title "Error" --msgbox "Failed to add torrent!\n\n$result" 12 60
    fi
}

action_start_torrent() {
    if [ ${#TORRENT_IDS[@]} -eq 0 ]; then
        dialog --title "Error" --msgbox "No torrents available!" 7 40
        return
    fi

    local id="${TORRENT_IDS[$SELECTED_ROW]}"
    local result=$(start_torrent "$id" 2>&1)

    if [ $? -eq 0 ]; then
        dialog --title "Success" --infobox "Torrent #$id started!" 5 40
        sleep 1
        refresh_torrent_data
    else
        dialog --title "Error" --msgbox "Failed to start!\n\n$result" 10 50
    fi
}

action_pause_torrent() {
    if [ ${#TORRENT_IDS[@]} -eq 0 ]; then
        dialog --title "Error" --msgbox "No torrents available!" 7 40
        return
    fi

    local id="${TORRENT_IDS[$SELECTED_ROW]}"
    local result=$(stop_torrent "$id" 2>&1)

    if [ $? -eq 0 ]; then
        dialog --title "Success" --infobox "Torrent #$id paused!" 5 40
        sleep 1
        refresh_torrent_data
    else
        dialog --title "Error" --msgbox "Failed to pause!\n\n$result" 10 50
    fi
}

action_delete_torrent() {
    if [ ${#TORRENT_IDS[@]} -eq 0 ]; then
        dialog --title "Error" --msgbox "No torrents available!" 7 40
        return
    fi

    local id="${TORRENT_IDS[$SELECTED_ROW]}"

    dialog --title "Confirm Delete" \
           --yesno "Delete torrent #$id and all its files?\n\nThis cannot be undone!" 8 50

    if [ $? -eq 0 ]; then
        local result=$(remove_torrent_with_files "$id" 2>&1)

        if [ $? -eq 0 ]; then
            dialog --title "Success" --infobox "Torrent #$id deleted!" 5 40
            sleep 1
            refresh_torrent_data
            [ $SELECTED_ROW -ge ${#TORRENT_IDS[@]} ] && SELECTED_ROW=$((${#TORRENT_IDS[@]} - 1))
            [ $SELECTED_ROW -lt 0 ] && SELECTED_ROW=0
        else
            dialog --title "Error" --msgbox "Failed to delete!\n\n$result" 10 50
        fi
    fi
}

action_verify_torrent() {
    if [ ${#TORRENT_IDS[@]} -eq 0 ]; then
        dialog --title "Error" --msgbox "No torrents available!" 7 40
        return
    fi

    local id="${TORRENT_IDS[$SELECTED_ROW]}"
    local result=$(verify_torrent "$id" 2>&1)

    if [ $? -eq 0 ]; then
        dialog --title "Success" --infobox "Verification started for #$id!" 5 40
        sleep 1
    else
        dialog --title "Error" --msgbox "Failed to verify!\n\n$result" 10 50
    fi
}

action_show_details() {
    if [ ${#TORRENT_IDS[@]} -eq 0 ]; then
        dialog --title "Error" --msgbox "No torrents available!" 7 40
        return
    fi

    local id="${TORRENT_IDS[$SELECTED_ROW]}"
    local info=$(get_torrent_info "$id" 2>/dev/null)

    if [ -z "$info" ]; then
        dialog --title "Error" --msgbox "Failed to get torrent info!" 7 40
        return
    fi

    local details=$(echo "$info" | grep -E "^[[:space:]]*(Name|State|Percent Done|Total size|Have|Download Speed|Upload Speed|ETA|Ratio|Peers|Location):" | head -15)

    dialog --title "Torrent #$id Details" \
           --msgbox "$details" 22 75
}

action_start_all() {
    local result=$(start_torrent "all" 2>&1)
    if [ $? -eq 0 ]; then
        dialog --title "Success" --infobox "All torrents started!" 5 40
        sleep 1
        refresh_torrent_data
    else
        dialog --title "Error" --msgbox "Failed!\n\n$result" 10 50
    fi
}

action_pause_all() {
    local result=$(stop_torrent "all" 2>&1)
    if [ $? -eq 0 ]; then
        dialog --title "Success" --infobox "All torrents paused!" 5 40
        sleep 1
        refresh_torrent_data
    else
        dialog --title "Error" --msgbox "Failed!\n\n$result" 10 50
    fi
}

toggle_auto_refresh() {
    if [ $AUTO_REFRESH -eq 1 ]; then
        AUTO_REFRESH=0
    else
        AUTO_REFRESH=1
    fi
}

# ============================================================================
# MAIN LOOP
# ============================================================================

main_loop() {
    local last_refresh=$(date +%s)

    while [ $RUNNING -eq 1 ]; do
        # Auto refresh
        local now=$(date +%s)
        if [ $AUTO_REFRESH -eq 1 ] && [ $((now - last_refresh)) -ge $REFRESH_INTERVAL ]; then
            refresh_torrent_data
            last_refresh=$now
        fi

        # Get terminal size
        get_terminal_size

        # Show dashboard and capture key
        dialog --colors \
               --no-shadow \
               --no-collapse \
               --timeout 1 \
               --title " BITS Downloader Dashboard " \
               --extra-button --extra-label "Refresh" \
               --ok-label "Action Menu" \
               --cancel-label "Quit" \
               --msgbox "$(build_dashboard_content)" \
               $TERM_HEIGHT $TERM_WIDTH 2> "$DIALOG_TEMP"

        local result=$?

        # Handle dialog result
        case $result in
            0)  # OK/Action Menu - show action menu
                show_action_menu
                ;;
            1)  # Cancel/Quit
                RUNNING=0
                ;;
            3)  # Extra button/Refresh
                refresh_torrent_data
                ;;
            255)  # Timeout - just refresh display
                ;;
        esac
    done
}

build_dashboard_content() {
    local status="STOPPED"
    local status_color="\Z1"
    if is_transmission_running; then
        status="RUNNING"
        status_color="\Z2"
    fi

    local torrent_count=${#TORRENT_IDS[@]}
    local content=""

    content+="\n\Zb\Z4═══════════════════════════════════════════════════════════════════════════════\Zn\n"
    content+="  \Zb\Z6BITS DOWNLOADER\Zn - Interactive Torrent Manager\n"
    content+="\Zb\Z4═══════════════════════════════════════════════════════════════════════════════\Zn\n\n"

    content+="  Status: ${status_color}\Zb${status}\Zn  |  "
    content+="Torrents: \Zb\Z3${torrent_count}\Zn  |  "
    content+="Auto-refresh: "
    if [ $AUTO_REFRESH -eq 1 ]; then
        content+="\Z2ON\Zn (${REFRESH_INTERVAL}s)"
    else
        content+="\Z1OFF\Zn"
    fi
    content+="\n\n"

    content+="\Zb\Z4┌──────┬────────────────────────────────────────┬────────────┬─────────┬──────────┐\Zn\n"
    content+="\Zb\Z4│\Zn \ZbID\Zn   \Zb\Z4│\Zn \ZbNAME\Zn                                   \Zb\Z4│\Zn \ZbSIZE\Zn       \Zb\Z4│\Zn \ZbDONE\Zn    \Zb\Z4│\Zn \ZbSTATUS\Zn   \Zb\Z4│\Zn\n"
    content+="\Zb\Z4├──────┼────────────────────────────────────────┼────────────┼─────────┼──────────┤\Zn\n"

    if [ ${#TORRENT_IDS[@]} -eq 0 ]; then
        content+="\Zb\Z4│\Zn                                                                             \Zb\Z4│\Zn\n"
        content+="\Zb\Z4│\Zn                    \Z3No torrents available\Zn                                \Zb\Z4│\Zn\n"
        content+="\Zb\Z4│\Zn                Click 'Action Menu' to add a torrent                          \Zb\Z4│\Zn\n"
        content+="\Zb\Z4│\Zn                                                                             \Zb\Z4│\Zn\n"
    else
        local max_display=10
        local start_idx=0

        if [ $SELECTED_ROW -ge $max_display ]; then
            start_idx=$((SELECTED_ROW - max_display + 1))
        fi

        local displayed=0
        for ((i=start_idx; i<${#TORRENT_IDS[@]} && displayed<max_display; i++)); do
            local id="${TORRENT_IDS[$i]}"
            local name="${TORRENT_DATA[${id}_name]}"
            local done="${TORRENT_DATA[${id}_done]}"
            local status="${TORRENT_DATA[${id}_status]}"
            local size="${TORRENT_DATA[${id}_size]}"

            name=$(echo "$name" | cut -c1-38)

            local done_color="\Z3"
            if [[ "$done" == "100%" ]]; then
                done_color="\Z2"
            fi

            local status_color="\Z7"
            if [[ "$status" =~ "Seeding" ]]; then
                status_color="\Z2"
            elif [[ "$status" =~ "Downloading" ]]; then
                status_color="\Z6"
            elif [[ "$status" =~ "Stopped" ]]; then
                status_color="\Z1"
            fi

            if [ $i -eq $SELECTED_ROW ]; then
                content+="\Zb\Z7\Zr"
            fi

            content+="\Zb\Z4│\Zn "
            printf -v id_str "%-5s" "$id"
            content+="${id_str} \Zb\Z4│\Zn "
            printf -v name_str "%-38s" "$name"
            content+="${name_str} \Zb\Z4│\Zn "
            printf -v size_str "%-10s" "$size"
            content+="${size_str} \Zb\Z4│\Zn "
            content+="${done_color}"
            printf -v done_str "%-7s" "$done"
            content+="${done_str}\Zn \Zb\Z4│\Zn "
            content+="${status_color}"
            printf -v status_str "%-8s" "$status"
            content+="${status_str}\Zn \Zb\Z4│\Zn"

            if [ $i -eq $SELECTED_ROW ]; then
                content+="\ZR"
            fi

            content+="\n"
            ((displayed++))
        done

        for ((j=displayed; j<max_display; j++)); do
            content+="\Zb\Z4│\Zn      \Zb\Z4│\Zn                                        \Zb\Z4│\Zn            \Zb\Z4│\Zn         \Zb\Z4│\Zn          \Zb\Z4│\Zn\n"
        done
    fi

    content+="\Zb\Z4└──────┴────────────────────────────────────────┴────────────┴─────────┴──────────┘\Zn\n\n"

    content+="\Zb\Z4═══════════════════════════════════════════════════════════════════════════════\Zn\n"
    content+="  Click \Zb'Action Menu'\Zn for torrent operations  •  Click \Zb'Refresh'\Zn to update  •  \Zb'Quit'\Zn to exit\n"
    content+="\Zb\Z4═══════════════════════════════════════════════════════════════════════════════\Zn"

    echo "$content"
}

show_action_menu() {
    if [ ${#TORRENT_IDS[@]} -eq 0 ]; then
        dialog --clear --title "Actions" \
               --menu "Select an action:" 15 60 7 \
               1 "Add Torrent" \
               2 "Start All" \
               3 "Pause All" \
               4 "Toggle Auto-Refresh" \
               5 "Back" \
               2> "$DIALOG_TEMP"
    else
        dialog --clear --title "Actions" \
               --menu "Select torrent #${TORRENT_IDS[$SELECTED_ROW]} or action:" 18 60 10 \
               1 "View Details (Selected)" \
               2 "Start (Selected)" \
               3 "Pause (Selected)" \
               4 "Delete (Selected)" \
               5 "Verify (Selected)" \
               6 "Add Torrent" \
               7 "Start All" \
               8 "Pause All" \
               9 "Select Next/Previous" \
               10 "Toggle Auto-Refresh" \
               11 "Back" \
               2> "$DIALOG_TEMP"
    fi

    if [ $? -eq 0 ]; then
        local choice=$(cat "$DIALOG_TEMP")
        handle_action $choice
    fi
    clear
}

handle_action() {
    local action=$1

    if [ ${#TORRENT_IDS[@]} -eq 0 ]; then
        case $action in
            1) action_add_torrent ;;
            2) action_start_all ;;
            3) action_pause_all ;;
            4) toggle_auto_refresh ;;
        esac
    else
        case $action in
            1) action_show_details ;;
            2) action_start_torrent ;;
            3) action_pause_torrent ;;
            4) action_delete_torrent ;;
            5) action_verify_torrent ;;
            6) action_add_torrent ;;
            7) action_start_all ;;
            8) action_pause_all ;;
            9) show_select_torrent ;;
            10) toggle_auto_refresh ;;
        esac
    fi
}

show_select_torrent() {
    local items=()
    for ((i=0; i<${#TORRENT_IDS[@]}; i++)); do
        local id="${TORRENT_IDS[$i]}"
        local name="${TORRENT_DATA[${id}_name]}"
        local done="${TORRENT_DATA[${id}_done]}"
        items+=("$i" "#$id: $name [$done]")
    done

    dialog --clear --title "Select Torrent" \
           --menu "Choose a torrent to select:" 20 70 12 \
           "${items[@]}" \
           2> "$DIALOG_TEMP"

    if [ $? -eq 0 ]; then
        SELECTED_ROW=$(cat "$DIALOG_TEMP")
    fi
    clear
}

# ============================================================================
# START
# ============================================================================

clear
refresh_torrent_data
main_loop
clear
echo "Goodbye!"
