#!/usr/bin/env bash

# bits-manager - Dialog-driven TUI wrapper for bits-downloader
# Uses dialog (ncurses) for navigation and launches the live terminal dashboard.

set -euo pipefail

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$BIN_DIR/.." && pwd)"

source "$PROJECT_ROOT/lib/config.sh"
source "$PROJECT_ROOT/lib/utils.sh"
source "$PROJECT_ROOT/lib/transmission_api.sh"

DIALOG_BIN="${DIALOG_BIN:-dialog}"
DIALOG_OPTS=(--no-shadow --no-lines)

dialog_cmd() {
    "$DIALOG_BIN" "${DIALOG_OPTS[@]}" "$@"
}

require_dialog() {
    if ! command -v "$DIALOG_BIN" >/dev/null 2>&1; then
        echo "dialog is required for the new UI. Please install it via your package manager."
        exit 1
    fi
}

cleanup_ui() {
    tput sgr0 2>/dev/null || true
    tput cnorm 2>/dev/null || true
    clear
}

ensure_setup() {
    ensure_directories
    mkdir -p "$PROJECT_ROOT/data"
    [ -f "$TORRENT_LIST" ] || touch "$TORRENT_LIST"
}

center_line() {
    local text="$1" width="$2"
    local pad=$(( (width - ${#text}) / 2 ))
    [ $pad -lt 0 ] && pad=0
    printf "%*s%s" "$pad" "" "$text"
}

show_splash() {
    local width=70
    local heading
    local subheading
    local credit
    heading=$(center_line "Welcome to Bits Downloader" "$width")
    subheading=$(center_line "Fast, bash-native torrent manager" "$width")
    credit=$(center_line "Made with <3 by bimmercodes" "$width")

    dialog_cmd --backtitle "BITS Downloader" --title "Welcome" \
        --msgbox "$heading\n$subheading\n$credit" 9 "$width"
}

start_manager() {
    ensure_setup

    if ! ensure_transmission_available; then
        dialog_cmd --title "Missing dependency" --msgbox "transmission-daemon is required. Please install transmission-cli/transmission-daemon packages and try again." 8 70
        return
    fi

    if pgrep -f "torrent_manager.sh" >/dev/null 2>&1; then
        dialog_cmd --title "Already Running" --msgbox "Torrent manager is already running." 6 50
        return
    fi

    nohup "$PROJECT_ROOT/lib/torrent_manager.sh" > "$LOG_DIR/nohup.log" 2>&1 &
    sleep 2

    if pgrep -f "torrent_manager.sh" >/dev/null 2>&1; then
        dialog_cmd --title "Started" --msgbox "Torrent manager is now running. Transmission will be started automatically if needed." 8 70
    else
        dialog_cmd --title "Error" --msgbox "Failed to start torrent manager. Check $LOG_DIR/nohup.log for details." 8 70
    fi
}

stop_manager() {
    stop_torrent "all" || true
    stop_transmission || true
    pkill -f "torrent_manager.sh" >/dev/null 2>&1 || true
    dialog_cmd --title "Stopped" --msgbox "All torrents paused and transmission-daemon stopped." 7 60
}

resume_all() {
    if is_transmission_running; then
        start_torrent "all"
        dialog_cmd --title "Resumed" --msgbox "All torrents resumed." 6 40
    else
        dialog_cmd --title "Not Running" --msgbox "Transmission is not running. Start it first." 6 60
    fi
}

pause_all() {
    if is_transmission_running; then
        stop_torrent "all"
        dialog_cmd --title "Paused" --msgbox "All torrents paused." 6 40
    else
        dialog_cmd --title "Not Running" --msgbox "Transmission is not running. Start it first." 6 60
    fi
}

launch_dashboard() {
    cleanup_ui
    "$PROJECT_ROOT/ui/terminal_dashboard.sh"
}

prompt_add_torrent() {
    ensure_setup

    if ! is_transmission_running; then
        dialog_cmd --title "Not Running" --yesno "Transmission is not running. Start it now?" 8 60
        case $? in
            0) start_manager ;;
            1|3) return ;; # cancel or ESC
        esac
    fi

    local torrent
    torrent=$(dialog_cmd --stdout --backtitle "Add Torrent" --title "Add Torrent" \
        --inputbox "Paste a magnet link, URL, or path to a .torrent file." 9 70) || return

    [ -z "$torrent" ] && return

    if add_torrent "$torrent" "$DOWNLOAD_DIR"; then
        dialog_cmd --title "Added" --msgbox "Torrent added successfully." 6 40
    else
        dialog_cmd --title "Error" --msgbox "Failed to add torrent. Verify the link or file path." 7 60
    fi
}

build_torrent_menu_options() {
    mapfile -t TORRENT_ROWS < <(transmission-remote -l 2>/dev/null | awk 'NR>1 && $1!="Sum:" {id=$1; $1=""; sub(/^ +/,""); printf "%s\t%s\n", id, $0}')
}

select_torrent() {
    build_torrent_menu_options
    [ ${#TORRENT_ROWS[@]} -eq 0 ] && return 2

    local options=()
    for row in "${TORRENT_ROWS[@]}"; do
        local id="${row%%$'\t'*}"
        local desc="${row#*$'\t'}"
        options+=("$id" "$desc")
    done

    local selection
    selection=$(dialog_cmd --stdout --backtitle "BITS Downloader" --title "Torrents" \
        --menu "Select a torrent to view details." 20 90 12 "${options[@]}")

    local status=$?
    [ $status -ne 0 ] && return $status
    echo "$selection"
}

show_torrent_details() {
    if ! is_transmission_running; then
        dialog_cmd --title "Not Running" --msgbox "Transmission is not running. Start it first." 6 60
        return
    fi

    local selection
    selection=$(select_torrent)
    local status=$?
    if [ $status -ne 0 ]; then
        [ $status -eq 2 ] && dialog_cmd --title "No Torrents" --msgbox "No torrents are currently available." 6 60
        return
    fi

    local details
    details=$(get_torrent_info "$selection" 2>/dev/null || echo "Unable to fetch torrent info.")

    dialog_cmd --title "Torrent #$selection" --msgbox "$details" 20 90
}

show_settings() {
    local running="OFF"
    is_transmission_running && running="ON"
    dialog_cmd --title "Settings" --msgbox "Transmission: $running\n\nDownload dir: $DOWNLOAD_DIR\nTorrent dir:  $TORRENT_DIR\nLogs dir:     $LOG_DIR\nTorrent list: $TORRENT_LIST" 12 80
}

menu_label_status() {
    local running="Stopped"
    local active="0"
    if is_transmission_running; then
        running="Running"
        active=$(get_active_count 2>/dev/null || echo "0")
    fi
    echo "Transmission: $running | Active: $active | Download dir: $DOWNLOAD_DIR"
}

main_menu() {
    while true; do
        local status_text
        status_text=$(menu_label_status)

        local choice
        choice=$(dialog_cmd --stdout --clear --backtitle "BITS Downloader" --title "Main Menu" \
            --menu "$status_text\n\nUse arrow keys to navigate and Enter to select." 20 80 10 \
            dashboard "Open live dashboard (Active Torrents UI)" \
            add "Add a new torrent (magnet/URL/file)" \
            details "View torrent details" \
            start "Start transmission + manager" \
            stop "Stop transmission + pause all" \
            resume "Resume all torrents" \
            pause "Pause all torrents" \
            settings "Show current paths and status" \
            quit "Exit")

        local status=$?
        # Cancel/ESC returns to menu; only quit choice exits.
        if [ $status -ne 0 ]; then
            continue
        fi

        # If the user pressed ESC/cancel, redisplay the menu instead of exiting the app
        if [ -z "${choice:-}" ]; then
            continue
        fi

        case "$choice" in
            dashboard) launch_dashboard ;;
            add) prompt_add_torrent ;;
            details) show_torrent_details ;;
            start) start_manager ;;
            stop) stop_manager ;;
            resume) resume_all ;;
            pause) pause_all ;;
            settings) show_settings ;;
            quit) break ;;
        esac
    done
}

main() {
    trap cleanup_ui EXIT INT TERM
    require_dialog
    ensure_setup
    show_splash
    main_menu
    cleanup_ui
}

main "$@"
