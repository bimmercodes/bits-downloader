#!/bin/bash

# bits-downloader - Main TUI Application
# by bimmercodes

set -e

# Configuration
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$BIN_DIR/.." && pwd)"
INSTALL_MARKER="$PROJECT_ROOT/.installed"
CONFIG_FILE="$PROJECT_ROOT/.config"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

# Function to show BITS-DOWNLOADER logo splash screen
show_splash() {
    clear
    echo -e "${BLUE}"
    cat << 'EOF'
  ____  _ _         _____                      _                 _           
 |  _ \(_) |       |  __ \                    | |               | |          
 | |_) |_| |_ ___  | |  | | _____      ___ __ | | ___   __ _  __| | ___ _ __ 
 |  _ <| | __/ __| | |  | |/ _ \ \ /\ / / '_ \| |/ _ \ / _` |/ _` |/ _ \ '__|
 | |_) | | |_\__ \ | |__| | (_) \ V  V /| | | | | (_) | (_| | (_| |  __/ |   
 |____/|_|\__|___/ |_____/ \___/ \_/\_/ |_| |_|_|\___/ \__,_|\__,_|\___|_|     
EOF
    echo -e "${NC}"
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${WHITE}BITS-DOWNLOADER - Torrent Management System${NC}    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}        ${GRAY}by bimmercodes${NC}                            ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    sleep 1.5
}

# Function to load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}

# Function to save configuration
save_config() {
    cat > "$CONFIG_FILE" << EOF
TORRENT_DIR="$TORRENT_DIR"
DOWNLOAD_DIR="$DOWNLOAD_DIR"
LOG_DIR="$LOG_DIR"
TORRENT_LIST="$TORRENT_LIST"
EOF
}

# Function to check if installation is complete
is_installed() {
    [ -f "$INSTALL_MARKER" ] && [ -f "$CONFIG_FILE" ]
}

# Function to run installation wizard
run_installation_wizard() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}INSTALLATION WIZARD${NC} ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Welcome to bits-downloader!${NC}"
    echo -e "${GRAY}This wizard will help you set up the torrent manager.${NC}"
    echo ""

    # Check if transmission is installed
    echo -e "${BLUE}[1/4]${NC} Checking transmission-daemon..."
    if ! command -v transmission-daemon &> /dev/null; then
        echo -e "${YELLOW}transmission-daemon not found. Installing...${NC}"
        echo ""
        read -p "Press Enter to install transmission packages (requires sudo)..."

        sudo apt-get update
        sudo apt-get install -y transmission-cli transmission-daemon transmission-common

        echo -e "${GREEN}✓ transmission-daemon installed${NC}"
    else
        echo -e "${GREEN}✓ transmission-daemon already installed${NC}"
    fi
    echo ""

    # Get download directory
    echo -e "${BLUE}[2/4]${NC} Configure download directory"
    echo -e "${GRAY}Where should downloaded files be saved?${NC}"
    echo -e "${GRAY}Default: $PROJECT_ROOT/downloads${NC}"
    read -p "Download directory [press Enter for default]: " user_download_dir

    if [ -z "$user_download_dir" ]; then
        DOWNLOAD_DIR="$PROJECT_ROOT/downloads"
    else
        # Expand ~ to home directory
        DOWNLOAD_DIR="${user_download_dir/#\~/$HOME}"
        # Convert to absolute path
        DOWNLOAD_DIR="$(cd "$(dirname "$DOWNLOAD_DIR")" 2>/dev/null && pwd)/$(basename "$DOWNLOAD_DIR")" || DOWNLOAD_DIR="$user_download_dir"
    fi

    echo -e "${GREEN}✓ Download directory: $DOWNLOAD_DIR${NC}"
    echo ""

    # Set other directories
    TORRENT_DIR="$PROJECT_ROOT/torrents"
    LOG_DIR="$PROJECT_ROOT/logs"
    TORRENT_LIST="$PROJECT_ROOT/data/torrent_list.txt"

    # Create directory structure
    echo -e "${BLUE}[3/4]${NC} Creating directory structure..."
    mkdir -p "$TORRENT_DIR/added"
    mkdir -p "$DOWNLOAD_DIR/.incomplete"
    mkdir -p "$LOG_DIR"
    echo -e "${GREEN}✓ Directories created${NC}"
    echo ""

    # Save configuration and ensure directories exist
    echo -e "${BLUE}[4/4]${NC} Saving configuration..."

    # Create torrent_list.txt if it doesn't exist
    if [ ! -f "$TORRENT_LIST" ]; then
        cat > "$TORRENT_LIST" << 'EOF'
# Torrent List - Add magnet links, URLs, or file paths (one per line)
# Lines starting with # are ignored
#
# Example formats:
# magnet:?xt=urn:btih:HASH&dn=NAME
# http://example.com/file.torrent
# /path/to/local/file.torrent
#
# Add your torrent links below:
EOF
    fi

    # Make all scripts executable
    chmod +x "$PROJECT_ROOT/bin"/*.sh "$PROJECT_ROOT/lib"/*.sh "$PROJECT_ROOT/ui"/*.sh 2>/dev/null

    # Save configuration
    save_config

    # Mark as installed
    touch "$INSTALL_MARKER"

    echo -e "${GREEN}✓ Configuration complete${NC}"
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  ${WHITE}Installation completed successfully!${NC}   ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Download directory: ${WHITE}$DOWNLOAD_DIR${NC}"
    echo -e "${CYAN}Torrent directory:  ${WHITE}$TORRENT_DIR${NC}"
    echo -e "${CYAN}Logs directory:     ${WHITE}$LOG_DIR${NC}"
    echo ""
    read -p "Press Enter to continue to main menu..."
}

# Function to show main menu
show_main_menu() {
    while true; do
        clear
        echo -e "${BLUE}"
        cat << 'EOF'
__________.__  __             ________                      .__                    .___            
\______   \__|/  |_  ______   \______ \   ______  _  ______ |  |   _________     __| _/___________ 
 |    |  _/  \   __\/  ___/    |    |  \ /  _ \ \/ \/ /    \|  |  /  _ \__  \   / __ |/ __ \_  __ \
 |    |   \  ||  |  \___ \     |    `   (  <_> )     /   |  \  |_(  <_> ) __ \_/ /_/ \  ___/|  | \/
 |______  /__||__| /____  >   /_______  /\____/ \/\_/|___|  /____/\____(____  /\____ |\___  >__|   
        \/              \/            \/                  \/                \/      \/    \/   
EOF
        echo -e "${NC}"
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}  ${WHITE}BITS-DOWNLOADER - Torrent Management System${NC}    ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}        ${GRAY}by bimmercodes${NC}                            ${CYAN}║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""

        # Check if torrent manager is running
        if pgrep -f "torrent_manager.sh" > /dev/null; then
            echo -e "${GREEN}● ${WHITE}Torrent Manager: ${GREEN}RUNNING${NC}"
        else
            echo -e "${GRAY}● ${WHITE}Torrent Manager: ${GRAY}STOPPED${NC}"
        fi

        echo ""
        echo -e "${CYAN}═══════════════════════════════════════════${NC}"
        echo -e "${WHITE}  MAIN MENU${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════${NC}"
        echo ""
        echo -e "  ${GREEN}1${NC}) ${WHITE}Start Torrent Manager${NC}"
        echo -e "  ${GREEN}2${NC}) ${WHITE}Stop Torrent Manager${NC}"
        echo -e "  ${GREEN}3${NC}) ${WHITE}Monitor Downloads${NC}"
        echo -e "  ${GREEN}4${NC}) ${WHITE}Control Panel${NC}"
        echo -e "  ${GREEN}5${NC}) ${WHITE}Add Torrent${NC}"
        echo -e "  ${GREEN}6${NC}) ${WHITE}View Logs${NC}"
        echo -e "  ${GREEN}7${NC}) ${WHITE}Settings${NC}"
        echo -e "  ${RED}0${NC}) ${WHITE}Exit${NC}"
        echo ""
        echo -e "${CYAN}═══════════════════════════════════════════${NC}"
        echo ""
        read -p "$(echo -e ${WHITE}Select option:${NC} )" choice

        case $choice in
            1)
                start_torrent_manager
                ;;
            2)
                stop_torrent_manager
                ;;
            3)
                monitor_downloads
                ;;
            4)
                control_panel
                ;;
            5)
                add_torrent
                ;;
            6)
                view_logs
                ;;
            7)
                settings_menu
                ;;
            0)
                echo ""
                echo -e "${YELLOW}Thanks for using bits-downloader!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                sleep 1
                ;;
        esac
    done
}

# Function to start torrent manager
start_torrent_manager() {
    clear
    echo -e "${CYAN}Starting Torrent Manager...${NC}"
    echo ""

    if pgrep -f "torrent_manager.sh" > /dev/null; then
        echo -e "${YELLOW}Torrent manager is already running!${NC}"
    else
        "$PROJECT_ROOT/bin/start_torrents.sh"
        sleep 2
    fi

    echo ""
    read -p "Press Enter to continue..."
}

# Function to stop torrent manager
stop_torrent_manager() {
    clear
    echo -e "${CYAN}Stopping Torrent Manager...${NC}"
    echo ""

    "$PROJECT_ROOT/bin/stop_torrents.sh"

    echo ""
    read -p "Press Enter to continue..."
}

# Function to monitor downloads
monitor_downloads() {
    if ! pgrep -f "torrent_manager.sh" > /dev/null; then
        clear
        echo -e "${RED}ERROR: Torrent manager is not running!${NC}"
        echo ""
        echo "Start it first from the main menu (option 1)"
        echo ""
        read -p "Press Enter to continue..."
        return
    fi

    "$PROJECT_ROOT/bin/monitor_torrents.sh"
}

# Function to control panel
control_panel() {
    if ! transmission-remote -l &>/dev/null; then
        clear
        echo -e "${RED}ERROR: Transmission-daemon is not running!${NC}"
        echo ""
        echo "Start the torrent manager first (option 1)"
        echo ""
        read -p "Press Enter to continue..."
        return
    fi

    "$PROJECT_ROOT/bin/torrent_control.sh"
}

# Function to add torrent
add_torrent() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}      ${WHITE}ADD TORRENT${NC}                        ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""

    if ! transmission-remote -l &>/dev/null; then
        echo -e "${RED}ERROR: Transmission-daemon is not running!${NC}"
        echo "Start the torrent manager first (option 1)"
        echo ""
        read -p "Press Enter to continue..."
        return
    fi

    echo -e "${WHITE}Enter magnet link, URL, or file path:${NC}"
    echo -e "${GRAY}(magnet:?xt=... or http://... or /path/to/file.torrent)${NC}"
    read -p "> " torrent

    if [ -z "$torrent" ]; then
        echo ""
        echo -e "${YELLOW}No torrent specified${NC}"
    else
        echo ""

        # Validate input
        if [[ "$torrent" =~ ^magnet: ]] || [[ "$torrent" =~ ^http ]] || [ -f "$torrent" ]; then
            echo "Adding torrent..."
            transmission-remote -a "$torrent" 2>&1

            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Torrent added successfully${NC}"
            else
                echo -e "${RED}✗ Failed to add torrent${NC}"
                echo -e "${YELLOW}Check that the link/file is valid${NC}"
            fi
        else
            echo -e "${RED}✗ Invalid input${NC}"
            echo -e "${YELLOW}Must be a magnet link, HTTP URL, or valid file path${NC}"
        fi
    fi

    echo ""
    read -p "Press Enter to continue..."
}

# Function to view logs
view_logs() {
    while true; do
        clear
        echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}      ${WHITE}VIEW LOGS${NC}                          ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${GREEN}1${NC}) ${WHITE}Torrent Manager Log${NC}"
        echo -e "  ${GREEN}2${NC}) ${WHITE}Transmission Log${NC}"
        echo -e "  ${GREEN}3${NC}) ${WHITE}Completed Downloads${NC}"
        echo -e "  ${GREEN}4${NC}) ${WHITE}Current Status${NC}"
        echo -e "  ${RED}0${NC}) ${WHITE}Back${NC}"
        echo ""
        read -p "$(echo -e ${WHITE}Select log:${NC} )" log_choice

        case $log_choice in
            1)
                if [ -f "$LOG_DIR/torrent_manager.log" ]; then
                    less "$LOG_DIR/torrent_manager.log"
                else
                    echo "Log file not found"
                    sleep 2
                fi
                ;;
            2)
                if [ -f "$LOG_DIR/transmission.log" ]; then
                    less "$LOG_DIR/transmission.log"
                else
                    echo "Log file not found"
                    sleep 2
                fi
                ;;
            3)
                if [ -f "$LOG_DIR/completed.log" ]; then
                    less "$LOG_DIR/completed.log"
                else
                    echo "No completed downloads yet"
                    sleep 2
                fi
                ;;
            4)
                if [ -f "$LOG_DIR/current_status.txt" ]; then
                    less "$LOG_DIR/current_status.txt"
                else
                    echo "Status file not found"
                    sleep 2
                fi
                ;;
            0)
                return
                ;;
            *)
                echo "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# Function to show settings
settings_menu() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}      ${WHITE}SETTINGS${NC}     ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}Current Configuration:${NC}"
    echo ""
    echo -e "  Download directory: ${CYAN}$DOWNLOAD_DIR${NC}"
    echo -e "  Torrent directory:  ${CYAN}$TORRENT_DIR${NC}"
    echo -e "  Logs directory:     ${CYAN}$LOG_DIR${NC}"
    echo -e "  Torrent list:       ${CYAN}$TORRENT_LIST${NC}"
    echo ""
    echo -e "${GRAY}To change settings, stop the torrent manager and${NC}"
    echo -e "${GRAY}run the reinstallation wizard.${NC}"
    echo ""
    read -p "Press Enter to continue..."
}

# Main execution
main() {
    # Show splash screen
    show_splash

    # Load configuration if exists
    load_config

    # Check if installation is needed
    if ! is_installed; then
        run_installation_wizard
        load_config
    fi

    # Show main menu
    show_main_menu
}

# Run main
main
