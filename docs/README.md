# BITS-DOWNLOADER

```
    ██████╗ ███╗   ███╗██╗    ██╗
    ██╔══██╗████╗ ████║██║    ██║
    ██████╔╝██╔████╔██║██║ █╗ ██║
    ██╔══██╗██║╚██╔╝██║██║███╗██║
    ██████╔╝██║ ╚═╝ ██║╚███╔███╔╝
    ╚═════╝ ╚═╝     ╚═╝ ╚══╝╚══╝
```

**by bimmercodes**

A comprehensive TUI (Text User Interface) torrent management system using Transmission daemon with enhanced monitoring and control features.

---

## Quick Reference

**First time?** Just run:
```bash
./bits-downloader.sh
```
Follow the installation wizard, then enjoy!

**Already installed?** Same command:
```bash
./bits-downloader.sh
```
Access all features from the main menu!

---

## Features

- **Beautiful TUI Interface**: Interactive terminal UI with ASCII art splash screen
- **One-time Installation**: Smart wizard that only runs on first launch
- **Customizable Paths**: Choose your own download directory during setup
- **Real-time Monitoring**: Live dashboard showing download progress, speeds, and statistics
- **Detailed Statistics**: View ETA, peer count, file sizes, and download progress
- **Interactive Control Panel**: Manage torrents with an easy-to-use menu system
- **Automatic File Management**: Intelligent file deletion with fallback mechanisms
- **Persistent Downloads**: Downloads continue even after SSH logout
- **Color-coded Interface**: Enhanced readability with color-coded output

## Quick Start

Simply run the main application:

```bash
./bits-downloader.sh
```

On **first run**, the installation wizard will:
1. Check and install transmission-daemon if needed
2. Ask for your preferred download directory
3. Create all necessary directories and scripts
4. Set up the configuration

On **subsequent runs**, you'll see the main menu with all available options.

## Main Menu

```
    ██████╗ ███╗   ███╗██╗    ██╗
    ██╔══██╗████╗ ████║██║    ██║
    ██████╔╝██╔████╔██║██║ █╗ ██║
    ██╔══██╗██║╚██╔╝██║██║███╗██║
    ██████╔╝██║ ╚═╝ ██║╚███╔███╔╝
    ╚═════╝ ╚═╝     ╚═╝ ╚══╝╚══╝

╔════════════════════════════════════════════╗
║      BITS-DOWNLOADER                       ║
║      by bimmercodes                        ║
╚════════════════════════════════════════════╝

● Torrent Manager: RUNNING

═══════════════════════════════════════════
  MAIN MENU
═══════════════════════════════════════════

  1) Start Torrent Manager
  2) Stop Torrent Manager
  3) Monitor Downloads
  4) Control Panel
  5) Add Torrent
  6) View Logs
  7) Settings
  0) Exit
```

## Usage Guide

### 1. Start Torrent Manager
Starts the background torrent service that manages all downloads.

### 2. Stop Torrent Manager
Safely stops the torrent service and transmission-daemon.

### 3. Monitor Downloads
Opens the real-time dashboard showing:

- **Overall speeds**: Total download/upload rates
- **Active downloads**:
  - Torrent ID and name
  - Progress percentage (e.g., 45%)
  - Downloaded vs Total size (e.g., 2.5 GB / 5.0 GB)
  - Current download speed
  - ETA (Estimated Time of Arrival)
  - Number of connected peers
- **Queued torrents**: Paused/stopped downloads
- **Recently completed**: Last 5 completed downloads
- **Disk usage**: Available space in download directory

### 4. Control Panel
Interactive menu for managing torrents:
1. Add torrent (magnet/URL/file)
2. Pause torrent
3. Resume torrent
4. Remove torrent (with improved file deletion)
5. Pause all
6. Resume all
7. Set download speed limit
8. Set upload speed limit
9. Show detailed info
0. Exit

### 5. Add Torrent
Quick add interface - enter a magnet link, URL, or file path directly.

### 6. View Logs
Access to all log files:
- Torrent Manager Log
- Transmission Log
- Completed Downloads
- Current Status

### 7. Settings
View current configuration including download directory, torrent directory, and log paths.

## Adding Torrents

### Method 1: Quick Add (TUI)
1. Run `./bits-downloader.sh`
2. Select option 5 (Add Torrent)
3. Enter magnet link, URL, or file path

### Method 2: Control Panel (TUI)
1. Run `./bits-downloader.sh`
2. Select option 4 (Control Panel)
3. Select option 1 (Add torrent)

### Method 3: Edit torrent_list.txt
Add magnet links or URLs to `torrent_list.txt` (one per line), then start the manager.

### Method 4: Place .torrent files
Copy `.torrent` files to the `torrents/` directory, then start the manager.

### Method 5: Command line (Advanced)
```bash
transmission-remote -a "magnet:?xt=..."
```

## Enhanced Features

### Monitor Improvements
- **Accurate ETA display**: Properly parsed from transmission daemon info
- **Peer statistics**: Shows number of connected peers for each torrent
- **Size tracking**: Displays both downloaded and total file sizes
- **Speed monitoring**: Individual download speeds per torrent
- **Detailed view**: Press `Ctrl+C` then `d` and enter torrent ID for full details

### File Deletion Improvements
When removing a torrent with files:
1. Transmission attempts to delete files using `--remove-and-delete`
2. If deletion fails, script automatically falls back to manual deletion
3. Provides clear feedback on deletion status
4. Handles permission issues gracefully

### Integrated Detailed View
Access full torrent information directly from the monitor:
- Press `Ctrl+C` once
- Type `d` when prompted
- Enter the torrent ID
- View complete torrent details
- Press Enter to return to monitoring

## Command Reference

### Basic Commands
```bash
# List all torrents
transmission-remote -l

# Pause a torrent
transmission-remote -t ID -S

# Resume a torrent
transmission-remote -t ID -s

# Remove torrent (keep files)
transmission-remote -t ID -r

# Remove torrent and delete files
transmission-remote -t ID --remove-and-delete

# Set download speed limit (KB/s, 0 = unlimited)
transmission-remote -d 500

# Set upload speed limit (KB/s, 0 = unlimited)
transmission-remote -u 100

# Show detailed torrent info
transmission-remote -t ID -i

# Show session statistics
transmission-remote -st

# Show session info
transmission-remote -si
```

## Logs

Monitor system activity through various log files:

```bash
# Main torrent manager log
tail -f ~/torrent_logs/torrent_manager.log

# Completed downloads
cat ~/torrent_logs/completed.log

# Current status snapshot
cat ~/torrent_logs/current_status.txt

# Transmission daemon log
tail -f ~/torrent_logs/transmission.log
```

## Directory Structure

```
bits-downloader/
├── bits-downloader.sh     # Main TUI application (START HERE!)
├── .installed             # Installation marker (auto-generated)
├── .config                # Configuration file (auto-generated)
├── downloads/             # Completed downloads (customizable)
│   └── .incomplete/       # In-progress downloads
├── torrents/              # .torrent files
│   └── added/             # Processed .torrent files
├── torrent_logs/          # Log files
│   ├── torrent_manager.log
│   ├── completed.log
│   ├── current_status.txt
│   └── transmission.log
├── torrent_list.txt       # List of magnet links/URLs
├── torrent_manager.sh     # Background service (auto-managed)
├── start_torrents.sh      # Service starter (auto-managed)
├── stop_torrents.sh       # Service stopper (auto-managed)
├── monitor_torrents.sh    # Live monitor (auto-managed)
└── torrent_control.sh     # Control panel (auto-managed)
```

## Persistence

- Service runs with `nohup` (survives SSH logout)
- Downloads continue in the background
- Reconnect anytime with `./monitor_torrents.sh`
- Service auto-starts all torrents on launch
- Completed torrents are automatically removed from queue

## Troubleshooting

### First Run Issues
**Q: The installer keeps asking for my download directory**
A: This is normal on first run only. Choose your preferred location (or press Enter for default).

**Q: Can I change my download directory later?**
A: Yes, you can view current settings in the Settings menu (option 7). To change, you'll need to stop the manager and manually edit the `.config` file.

### Service Issues

**Q: Check if service is running**
```bash
pgrep -f torrent_manager.sh
```
Or check the status indicator in the main menu.

**Q: Check transmission daemon**
```bash
transmission-remote -l
```

**Q: Restart the service**
Use the TUI:
1. Run `./bits-downloader.sh`
2. Select option 2 (Stop)
3. Select option 1 (Start)

Or via command line:
```bash
./stop_torrents.sh && ./start_torrents.sh
```

### Connection Issues

**Q: Monitor won't connect**
- Ensure torrent manager is running (option 1 in main menu)
- Check if port 9091 is available: `sudo netstat -tlnp | grep 9091`
- Verify transmission service: `transmission-remote -si`

**Q: View error logs**
```bash
tail torrent_logs/torrent_manager.log
```
Or use option 6 in the main menu.

### File Issues

**Q: Files not deleting**
- The control panel includes automatic fallback deletion
- Check file permissions in download directory
- Manually remove if needed: `rm -rf downloads/filename`

### Migration from Old Version

**Q: I was using the old install_torrents_manager.sh script**
A: The old script still exists but is no longer needed. Simply run `./bits-downloader.sh` instead. Your existing torrents and configuration will be preserved.

## Color Legend (Monitor)

- **Blue**: Headers and system information
- **Green**: Active downloads and success messages
- **Yellow**: Overall speeds and queued torrents
- **Cyan**: Torrent names and ETA
- **Magenta**: Torrent IDs
- **Red**: Errors and warnings

## Tips

1. **Speed Limits**: Set reasonable upload limits to avoid ISP throttling
2. **Disk Space**: Monitor disk usage regularly (shown in monitor)
3. **Peer Count**: Higher peer count usually means faster downloads
4. **ETA Accuracy**: ETA becomes more accurate as download progresses
5. **Background Running**: Use `screen` or `tmux` for persistent monitoring sessions

## Recent Updates

### Version 3.0 - TUI Overhaul

✓ **Beautiful TUI Interface**
- ASCII BMW logo splash screen on startup
- Unified interface through single entry point
- Color-coded menus with intuitive navigation
- Real-time status indicators

✓ **Smart Installation Wizard**
- Singleton pattern - only runs on first launch
- Interactive directory selection for downloads
- Automatic transmission-daemon installation
- Configuration persistence

✓ **Streamlined User Experience**
- All features accessible from main menu
- No need to remember different script names
- Status indicators show manager state
- Quick access to all functions

✓ **Enhanced Monitor Display** (v2.0)
- Accurate ETA parsing from transmission info
- Real-time peer count display
- Total file size vs downloaded amount tracking
- Individual download speeds per torrent
- Improved color-coded output for better readability

✓ **Improved File Deletion** (v2.0)
- Automatic fallback mechanism when transmission can't delete files
- Manual cleanup ensures complete file removal
- Better error handling and user feedback
- Permission issue detection and resolution

## License

This is free and open source software. Use it however you like.

## Contributing

Feel free to submit issues, feature requests, or pull requests to improve this tool.
