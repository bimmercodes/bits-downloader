#!/bin/bash

# BITS-DOWNLOADER - Uninstaller
# Safely removes bits-downloader and cleans up all components

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$SCRIPT_DIR"

# Banner
show_banner() {
    clear
    echo -e "${RED}"
    cat << 'EOF'
    ██████╗ ███╗   ███╗██╗    ██╗
    ██╔══██╗████╗ ████║██║    ██║
    ██████╔╝██╔████╔██║██║ █╗ ██║
    ██╔══██╗██║╚██╔╝██║██║███╗██║
    ██████╔╝██║ ╚═╝ ██║╚███╔███╔╝
    ╚═════╝ ╚═╝     ╚═╝ ╚══╝╚══╝
EOF
    echo -e "${NC}"
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}      ${WHITE}BITS-DOWNLOADER UNINSTALLER${NC}       ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}      ${WHITE}by bimmercodes${NC}                     ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
}

# Confirm uninstallation
confirm_uninstall() {
    echo -e "${YELLOW}WARNING: This will remove bits-downloader and stop all torrents${NC}"
    echo -e "${YELLOW}Installation directory: ${WHITE}$INSTALL_DIR${NC}"
    echo ""

    # Check if there are active downloads
    if pgrep -f "transmission-daemon" > /dev/null; then
        echo -e "${RED}Active transmission daemon detected!${NC}"

        # Try to get torrent count
        TORRENT_COUNT=$(transmission-remote -l 2>/dev/null | grep -v "^ID" | grep -v "Sum:" | wc -l)
        if [ "$TORRENT_COUNT" -gt 0 ]; then
            echo -e "${YELLOW}You have ${WHITE}$TORRENT_COUNT${YELLOW} torrent(s) in the queue${NC}"
        fi
        echo ""
    fi

    read -p "$(echo -e ${RED}Are you sure you want to uninstall? \(y/N\): ${NC})" -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Uninstallation cancelled${NC}"
        exit 0
    fi

    # Ask about downloads directory
    if [ -d "$INSTALL_DIR/downloads" ] && [ "$(ls -A "$INSTALL_DIR/downloads" 2>/dev/null)" ]; then
        echo ""
        echo -e "${YELLOW}Your downloads directory contains files${NC}"
        read -p "$(echo -e ${CYAN}Do you want to keep your downloaded files? \(Y/n\): ${NC})" -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            KEEP_DOWNLOADS=false
        else
            KEEP_DOWNLOADS=true
        fi
    else
        KEEP_DOWNLOADS=false
    fi
}

# Stop services
stop_services() {
    echo -e "${BLUE}[1/4]${NC} Stopping services..."

    # Stop torrent manager
    if pgrep -f "torrent_manager.sh" > /dev/null; then
        echo -e "${YELLOW}Stopping torrent manager...${NC}"
        pkill -f "torrent_manager.sh" 2>/dev/null || true
        sleep 2
    fi

    # Stop transmission daemon
    if pgrep -f "transmission-daemon" > /dev/null; then
        echo -e "${YELLOW}Stopping transmission daemon...${NC}"
        transmission-daemon --stop 2>/dev/null || true
        sleep 2

        # Force kill if still running
        if pgrep -f "transmission-daemon" > /dev/null; then
            pkill -9 transmission-daemon 2>/dev/null || true
        fi
    fi

    # Clean up PID file
    rm -f /tmp/torrent_manager.pid

    echo -e "${GREEN}✓ Services stopped${NC}"
    echo ""
}

# Remove launcher
remove_launcher() {
    echo -e "${BLUE}[2/4]${NC} Removing launcher..."

    # Remove ~/bits launcher
    if [ -f "$HOME/bits" ]; then
        rm -f "$HOME/bits"
        echo -e "${GREEN}✓ Removed ~/bits launcher${NC}"
    fi

    # Remove PATH entry from .bashrc
    if [ -f "$HOME/.bashrc" ]; then
        if grep -q "export PATH=\"\$HOME:\$PATH\"" "$HOME/.bashrc" 2>/dev/null; then
            # Create backup
            cp "$HOME/.bashrc" "$HOME/.bashrc.bits-backup"
            # Remove the line
            sed -i '/export PATH="\$HOME:\$PATH"/d' "$HOME/.bashrc"
            echo -e "${GREEN}✓ Cleaned up .bashrc (backup created: ~/.bashrc.bits-backup)${NC}"
        fi
    fi

    echo ""
}

# Save downloads
save_downloads() {
    if [ "$KEEP_DOWNLOADS" = true ] && [ -d "$INSTALL_DIR/downloads" ]; then
        echo -e "${BLUE}[3/4]${NC} Preserving downloads..."

        BACKUP_DIR="$HOME/bits-downloader-downloads-backup"
        mkdir -p "$BACKUP_DIR"

        echo -e "${YELLOW}Moving downloads to: ${WHITE}$BACKUP_DIR${NC}"
        mv "$INSTALL_DIR/downloads"/* "$BACKUP_DIR/" 2>/dev/null || true

        echo -e "${GREEN}✓ Downloads saved to $BACKUP_DIR${NC}"
        echo ""
    else
        echo -e "${BLUE}[3/4]${NC} Skipping downloads backup..."
        echo ""
    fi
}

# Remove installation directory
remove_installation() {
    echo -e "${BLUE}[4/4]${NC} Removing installation directory..."

    if [ -d "$INSTALL_DIR" ]; then
        # If we're running from install dir, we need to be careful
        CURRENT_DIR=$(pwd)
        if [[ "$CURRENT_DIR" == "$INSTALL_DIR"* ]]; then
            cd "$HOME"
        fi

        rm -rf "$INSTALL_DIR"
        echo -e "${GREEN}✓ Installation directory removed${NC}"
    fi

    echo ""
}

# Show completion
show_completion() {
    echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  ${WHITE}Uninstallation completed successfully!${NC} ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
    echo ""

    if [ "$KEEP_DOWNLOADS" = true ]; then
        echo -e "${CYAN}Your downloads have been saved to:${NC}"
        echo -e "  ${WHITE}$HOME/bits-downloader-downloads-backup/${NC}"
        echo ""
    fi

    echo -e "${WHITE}What was removed:${NC}"
    echo -e "  ${CYAN}✓${NC} bits-downloader installation directory"
    echo -e "  ${CYAN}✓${NC} Transmission daemon processes"
    echo -e "  ${CYAN}✓${NC} ~/bits launcher script"
    echo -e "  ${CYAN}✓${NC} Background services and logs"
    echo ""

    echo -e "${WHITE}What was NOT removed:${NC}"
    echo -e "  ${CYAN}•${NC} transmission-daemon package (still installed)"
    echo -e "  ${CYAN}•${NC} System packages and dependencies"

    if [ -f "$HOME/.bashrc.bits-backup" ]; then
        echo -e "  ${CYAN}•${NC} .bashrc backup: ~/.bashrc.bits-backup"
    fi

    echo ""
    echo -e "${YELLOW}To remove transmission completely, run:${NC}"
    echo -e "  ${WHITE}sudo apt-get remove transmission-cli transmission-daemon transmission-common${NC}"
    echo ""
    echo -e "${GREEN}Thank you for using bits-downloader!${NC}"
    echo -e "${BLUE}Made with ❤️  by bimmercodes${NC}"
    echo ""
}

# Main uninstallation flow
main() {
    show_banner
    confirm_uninstall
    stop_services
    remove_launcher
    save_downloads
    remove_installation
    show_completion
}

# Run uninstaller
main
