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
    ██████╗ ██╗████████╗███████╗      ██████╗  ██████╗ ██╗    ██╗███╗   ██╗██╗      ██████╗  █████╗ ██████╗ ███████╗██████╗
    ██╔══██╗██║╚══██╔══╝██╔════╝      ██╔══██╗██╔═══██╗██║    ██║████╗  ██║██║     ██╔═══██╗██╔══██╗██╔══██╗██╔════╝██╔══██╗
    ██████╔╝██║   ██║   ███████╗█████╗██║  ██║██║   ██║██║ █╗ ██║██╔██╗ ██║██║     ██║   ██║███████║██║  ██║█████╗  ██████╔╝
    ██╔══██╗██║   ██║   ╚════██║╚════╝██║  ██║██║   ██║██║███╗██║██║╚██╗██║██║     ██║   ██║██╔══██║██║  ██║██╔══╝  ██╔══██╗
    ██████╔╝██║   ██║   ███████║      ██████╔╝╚██████╔╝╚███╔███╔╝██║ ╚████║███████╗╚██████╔╝██║  ██║██████╔╝███████╗██║  ██║
    ╚═════╝ ╚═╝   ╚═╝   ╚══════╝      ╚═════╝  ╚═════╝  ╚══╝╚══╝ ╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝
EOF
    echo -e "${NC}"
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                                      ${WHITE}BITS-DOWNLOADER - Torrent Management System${NC}                                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                  ${GRAY}by bimmercodes${NC}                                                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝${NC}"
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
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}      ${WHITE}INSTALLATION WIZARD${NC}                ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
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

    # Create/update scripts with new paths
    echo -e "${BLUE}[4/4]${NC} Generating configuration files..."

    # Update torrent_manager.sh
    cat > "$PROJECT_ROOT/lib/torrent_manager.sh" << EOF
#!/bin/bash

# Configuration
TORRENT_DIR="$TORRENT_DIR"
DOWNLOAD_DIR="$DOWNLOAD_DIR"
LOG_DIR="$LOG_DIR"
TORRENT_LIST="$TORRENT_LIST"
MAIN_LOG="\$LOG_DIR/torrent_manager.log"
PID_FILE="/tmp/torrent_manager.pid"

# Create directories
mkdir -p "\$TORRENT_DIR" "\$DOWNLOAD_DIR" "\$LOG_DIR"

# Logging function
log_message() {
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1" | tee -a "\$MAIN_LOG"
}

# Check if already running
if [ -f "\$PID_FILE" ]; then
    OLD_PID=\$(cat "\$PID_FILE")
    if ps -p "\$OLD_PID" > /dev/null 2>&1; then
        log_message "ERROR: Torrent manager already running with PID \$OLD_PID"
        exit 1
    else
        rm -f "\$PID_FILE"
    fi
fi

# Save PID
echo \$\$ > "\$PID_FILE"

# Trap to cleanup on exit
trap 'rm -f "\$PID_FILE"; log_message "Torrent manager stopped"' EXIT

log_message "Starting torrent manager..."

# Stop any existing transmission-daemon
transmission-daemon --stop 2>/dev/null
sleep 2

# Start transmission-daemon with configuration
transmission-daemon \\
    --download-dir "\$DOWNLOAD_DIR" \\
    --incomplete-dir "\$DOWNLOAD_DIR/.incomplete" \\
    --logfile "\$LOG_DIR/transmission.log" \\
    --log-level=2 \\
    --encryption-preferred \\
    --peer-limit-global=200 \\
    --peer-limit-per-torrent=50 \\
    --download-queue-size=10 \\
    --seed-queue-size=10 \\
    --no-auth \\
    --allowed "127.0.0.1" \\
    --port 9091

sleep 3

# Check if daemon started
if ! transmission-remote -l &>/dev/null; then
    log_message "ERROR: Failed to start transmission-daemon"
    exit 1
fi

log_message "Transmission-daemon started successfully"

# Add torrents from list or directory
if [ -f "\$TORRENT_LIST" ]; then
    log_message "Adding torrents from list..."
    while IFS= read -r torrent; do
        [ -z "\$torrent" ] || [[ "\$torrent" =~ ^# ]] && continue

        if [[ "\$torrent" =~ ^magnet: ]] || [[ "\$torrent" =~ ^http ]]; then
            transmission-remote -a "\$torrent" &>/dev/null
            if [ \$? -eq 0 ]; then
                log_message "Added: \$torrent"
            else
                log_message "Failed to add: \$torrent"
            fi
        elif [ -f "\$torrent" ]; then
            transmission-remote -a "\$torrent" &>/dev/null
            if [ \$? -eq 0 ]; then
                log_message "Added file: \$torrent"
            else
                log_message "Failed to add file: \$torrent"
            fi
        fi
    done < "\$TORRENT_LIST"
fi

# Add any .torrent files from torrent directory
for torrent_file in "\$TORRENT_DIR"/*.torrent; do
    [ -f "\$torrent_file" ] || continue
    transmission-remote -a "\$torrent_file" &>/dev/null
    if [ \$? -eq 0 ]; then
        log_message "Added torrent file: \$(basename "\$torrent_file")"
        mv "\$torrent_file" "\$TORRENT_DIR/added/"
    fi
done

# Start all torrents
transmission-remote -t all -s
log_message "Started all torrents"

# Monitor loop
while true; do
    # Get status
    STATUS=\$(transmission-remote -l 2>/dev/null)

    if [ \$? -ne 0 ]; then
        log_message "WARNING: Cannot connect to transmission-daemon"
        sleep 30
        continue
    fi

    # Parse active downloads
    ACTIVE=\$(echo "\$STATUS" | grep -E "Downloading|Seeding" | wc -l)
    TOTAL=\$(echo "\$STATUS" | tail -n 1 | awk '{print \$1}')

    # Log summary every 5 minutes
    log_message "Status: Active: \$ACTIVE | Total in queue: \$TOTAL"

    # Detailed status to separate file
    echo "\$STATUS" > "\$LOG_DIR/current_status.txt"

    # Check completed
    while IFS= read -r line; do
        if echo "\$line" | grep -q "100%.*Seeding"; then
            ID=\$(echo "\$line" | awk '{print \$1}' | tr -d '*')
            NAME=\$(transmission-remote -t "\$ID" -i | grep "Name:" | cut -d: -f2- | xargs)
            if [ -n "\$NAME" ]; then
                echo "[\$(date '+%Y-%m-%d %H:%M:%S')] COMPLETED: \$NAME" >> "\$LOG_DIR/completed.log"
                transmission-remote -t "\$ID" --remove-and-delete &>/dev/null
            fi
        fi
    done <<< "\$STATUS"

    sleep 300  # Check every 5 minutes
done
EOF

    # Update start_torrents.sh
    cat > "$PROJECT_ROOT/bin/start_torrents.sh" << EOF
#!/bin/bash

PROJECT_ROOT="$PROJECT_ROOT"
LOG_DIR="$LOG_DIR"
mkdir -p "\$LOG_DIR"

# Check if already running
if pgrep -f "torrent_manager.sh" > /dev/null; then
    echo "Torrent manager is already running!"
    echo "Use ./bin/bits-downloader.sh to access the monitor"
    exit 1
fi

# Make scripts executable
chmod +x "\$PROJECT_ROOT/lib/torrent_manager.sh"
chmod +x "\$PROJECT_ROOT/bin/monitor_torrents.sh"
chmod +x "\$PROJECT_ROOT/bin/stop_torrents.sh"

echo "Starting torrent manager in background..."

# Start with nohup
nohup "\$PROJECT_ROOT/lib/torrent_manager.sh" > "\$LOG_DIR/nohup.log" 2>&1 &

echo "Torrent manager started with PID: \$!"
echo ""
echo "Use ./bin/bits-downloader.sh to monitor and control torrents"
EOF

    # Update stop_torrents.sh
    cat > "$PROJECT_ROOT/bin/stop_torrents.sh" << EOF
#!/bin/bash

echo "Stopping torrent manager..."

# Kill torrent manager script
if pgrep -f "torrent_manager.sh" > /dev/null; then
    pkill -f "torrent_manager.sh"
    echo "Torrent manager stopped"
else
    echo "Torrent manager was not running"
fi

# Stop transmission-daemon
if transmission-remote -l &>/dev/null; then
    echo "Stopping transmission-daemon..."
    transmission-daemon --stop
    sleep 2
    echo "Transmission-daemon stopped"
else
    echo "Transmission-daemon was not running"
fi

# Remove PID file
rm -f /tmp/torrent_manager.pid

echo "All torrent services stopped"
EOF

    # Update monitor_torrents.sh with new paths
    sed -i "s|LOG_DIR=.*|LOG_DIR=\"$LOG_DIR\"|g" "$PROJECT_ROOT/bin/monitor_torrents.sh"
    sed -i "s|DOWNLOAD_DIR=.*|DOWNLOAD_DIR=\"$DOWNLOAD_DIR\"|g" "$PROJECT_ROOT/bin/monitor_torrents.sh"

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
    ██████╗ ██╗████████╗███████╗      ██████╗  ██████╗ ██╗    ██╗███╗   ██╗██╗      ██████╗  █████╗ ██████╗ ███████╗██████╗
    ██╔══██╗██║╚══██╔══╝██╔════╝      ██╔══██╗██╔═══██╗██║    ██║████╗  ██║██║     ██╔═══██╗██╔══██╗██╔══██╗██╔════╝██╔══██╗
    ██████╔╝██║   ██║   ███████╗█████╗██║  ██║██║   ██║██║ █╗ ██║██╔██╗ ██║██║     ██║   ██║███████║██║  ██║█████╗  ██████╔╝
    ██╔══██╗██║   ██║   ╚════██║╚════╝██║  ██║██║   ██║██║███╗██║██║╚██╗██║██║     ██║   ██║██╔══██║██║  ██║██╔══╝  ██╔══██╗
    ██████╔╝██║   ██║   ███████║      ██████╔╝╚██████╔╝╚███╔███╔╝██║ ╚████║███████╗╚██████╔╝██║  ██║██████╔╝███████╗██║  ██║
    ╚═════╝ ╚═╝   ╚═╝   ╚══════╝      ╚═════╝  ╚═════╝  ╚══╝╚══╝ ╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝
EOF
        echo -e "${NC}"
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}                                      ${WHITE}BITS-DOWNLOADER - Torrent Management System${NC}                                  ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                  ${GRAY}by bimmercodes${NC}                                                    ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝${NC}"
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
    read -p "> " torrent

    if [ -z "$torrent" ]; then
        echo -e "${YELLOW}No torrent specified${NC}"
    else
        echo ""
        echo "Adding torrent..."
        transmission-remote -a "$torrent"

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Torrent added successfully${NC}"
        else
            echo -e "${RED}✗ Failed to add torrent${NC}"
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
    echo -e "${CYAN}║${NC}      ${WHITE}SETTINGS${NC}                           ${CYAN}║${NC}"
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
