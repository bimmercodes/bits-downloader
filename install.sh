#!/bin/bash

# BITS-DOWNLOADER - One-Line Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/bimmercodes/bits-downloader/main/install.sh | bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

# Configuration
REPO_URL="https://github.com/bimmercodes/bits-downloader.git"
INSTALL_DIR="$HOME/bits-downloader"

# Banner
show_banner() {
    clear
    echo -e "${BLUE}"
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
    echo -e "${CYAN}║${NC}      ${WHITE}BITS-DOWNLOADER INSTALLER${NC}         ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}      ${WHITE}by bimmercodes${NC}                     ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
}

# Check requirements
check_requirements() {
    echo -e "${BLUE}[1/5]${NC} Checking requirements..."

    # Check git
    if ! command -v git &> /dev/null; then
        echo -e "${RED}✗ git is not installed${NC}"
        echo -e "${YELLOW}Installing git...${NC}"
        sudo apt-get update && sudo apt-get install -y git
    else
        echo -e "${GREEN}✓ git is installed${NC}"
    fi

    # Check curl/wget
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        echo -e "${YELLOW}Installing curl...${NC}"
        sudo apt-get install -y curl
    fi

    echo ""
}

# Clone repository
clone_repo() {
    echo -e "${BLUE}[2/5]${NC} Downloading bits-downloader..."

    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}Directory already exists: $INSTALL_DIR${NC}"
        read -p "Remove and reinstall? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$INSTALL_DIR"
        else
            echo -e "${RED}Installation cancelled${NC}"
            exit 1
        fi
    fi

    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"

    echo -e "${GREEN}✓ Repository cloned${NC}"
    echo ""
}

# Install transmission
install_transmission() {
    echo -e "${BLUE}[3/5]${NC} Checking transmission-daemon..."

    if ! command -v transmission-daemon &> /dev/null; then
        echo -e "${YELLOW}transmission-daemon not found${NC}"
        echo -e "${CYAN}Installing transmission packages...${NC}"
        echo ""
        sudo apt-get update
        sudo apt-get install -y transmission-cli transmission-daemon transmission-common

        # Stop system transmission service if running
        sudo systemctl stop transmission-daemon 2>/dev/null || true
        sudo systemctl disable transmission-daemon 2>/dev/null || true

        echo -e "${GREEN}✓ transmission-daemon installed${NC}"
    else
        echo -e "${GREEN}✓ transmission-daemon already installed${NC}"

        # Ensure system service is not interfering
        if systemctl is-active --quiet transmission-daemon; then
            echo -e "${YELLOW}Stopping system transmission service...${NC}"
            sudo systemctl stop transmission-daemon
            sudo systemctl disable transmission-daemon
        fi
    fi

    echo ""
}

# Setup directories
setup_directories() {
    echo -e "${BLUE}[4/5]${NC} Setting up directory structure..."

    mkdir -p "$INSTALL_DIR/downloads"
    mkdir -p "$INSTALL_DIR/torrents/added"
    mkdir -p "$INSTALL_DIR/logs"
    mkdir -p "$INSTALL_DIR/data"

    # Make scripts executable
    chmod +x "$INSTALL_DIR/bin"/*.sh 2>/dev/null || true
    chmod +x "$INSTALL_DIR/lib"/*.sh 2>/dev/null || true
    chmod +x "$INSTALL_DIR/ui"/*.sh 2>/dev/null || true

    echo -e "${GREEN}✓ Directories created${NC}"
    echo -e "${GREEN}✓ Scripts made executable${NC}"
    echo ""
}

# Create launcher
create_launcher() {
    echo -e "${BLUE}[5/5]${NC} Creating launcher..."

    # Create a simple launcher script in home directory
    cat > "$HOME/bits" << 'LAUNCHER'
#!/bin/bash
cd "$HOME/bits-downloader"
./bin/bits-downloader.sh "$@"
LAUNCHER

    chmod +x "$HOME/bits"

    # Try to add to PATH via .bashrc if not already there
    if ! grep -q "export PATH=\"\$HOME:\$PATH\"" "$HOME/.bashrc" 2>/dev/null; then
        echo 'export PATH="$HOME:$PATH"' >> "$HOME/.bashrc"
    fi

    echo -e "${GREEN}✓ Launcher created: ~/bits${NC}"
    echo ""
}

# Show completion
show_completion() {
    echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  ${WHITE}Installation completed successfully!${NC}   ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Installation directory:${NC} ${WHITE}$INSTALL_DIR${NC}"
    echo ""
    echo -e "${WHITE}Quick Start:${NC}"
    echo -e "  ${CYAN}1.${NC} Run: ${YELLOW}cd $INSTALL_DIR${NC}"
    echo -e "  ${CYAN}2.${NC} Run: ${YELLOW}./bin/bits-downloader.sh${NC}"
    echo ""
    echo -e "${WHITE}Or simply run from anywhere:${NC}"
    echo -e "  ${YELLOW}~/bits${NC}"
    echo ""
    echo -e "${WHITE}For a quick demo of the UI:${NC}"
    echo -e "  ${YELLOW}cd $INSTALL_DIR && ./ui/demo_responsive.sh${NC}"
    echo ""
    echo -e "${WHITE}Full documentation:${NC}"
    echo -e "  ${CYAN}https://github.com/bimmercodes/bits-downloader${NC}"
    echo ""
    echo -e "${MAGENTA}Tip: Restart your terminal or run 'source ~/.bashrc' to use '~/bits' from anywhere${NC}"
    echo ""
    echo -e "${GREEN}Thank you for installing bits-downloader!${NC}"
    echo -e "${BLUE}Made with ❤️  by bimmercodes${NC}"
    echo ""
}

# Main installation flow
main() {
    show_banner
    check_requirements
    clone_repo
    install_transmission
    setup_directories
    create_launcher
    show_completion

    # Ask if user wants to start now
    read -p "$(echo -e ${CYAN}Start bits-downloader now? \(Y/n\): ${NC})" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        cd "$INSTALL_DIR"
        ./bin/bits-downloader.sh
    fi
}

# Run installer
main
