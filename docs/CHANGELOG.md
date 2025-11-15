# Changelog

## Version 3.0 - TUI Overhaul (2025-11-15)

### Major Changes

#### New TUI Application
- **NEW**: `bits-downloader.sh` - Main TUI entry point with ASCII BITS-DOWNLOADER logo
- Beautiful splash screen on startup
- Unified interface for all operations
- Color-coded menus with intuitive navigation
- Real-time status indicators showing manager state

#### Smart Installation System
- **Singleton Installation**: Only runs setup wizard on first launch
- Installation marker (`.installed`) prevents re-installation
- Configuration persistence (`.config` file)
- Interactive directory selection during setup
- Automatic transmission-daemon installation check
- Customizable download directory path

#### Improved User Experience
- All features accessible from single main menu:
  1. Start Torrent Manager
  2. Stop Torrent Manager
  3. Monitor Downloads
  4. Control Panel
  5. Add Torrent (quick add)
  6. View Logs (all logs in one place)
  7. Settings (view configuration)
  0. Exit

- No need to remember multiple script names
- Clear status indicators
- Consistent color scheme throughout
- Interactive prompts with clear instructions

#### Configuration Management
- Auto-generated `.config` file stores:
  - Torrent directory path
  - Download directory path (user-customizable)
  - Log directory path
  - Torrent list file path
- Configuration loaded on each run
- Settings viewable in TUI menu

#### Enhanced Scripts
- Updated `torrent_manager.sh` with configurable paths
- Updated `start_torrents.sh` with proper path references
- Updated `stop_torrents.sh` with improved cleanup
- Updated `monitor_torrents.sh` with configurable paths
- All scripts now work with custom download directories

#### Documentation
- **NEW**: `QUICKSTART.md` - 30-second getting started guide
- **UPDATED**: `README.md` - Complete rewrite for TUI usage
- Improved troubleshooting section
- Added migration guide for old users
- Better organized with quick reference at top

### Technical Improvements

#### Installation Wizard Flow
```
Splash Screen
    ↓
Check .installed marker
    ↓
[First Run] → Installation Wizard
              ├─ Check transmission-daemon
              ├─ Install if needed
              ├─ Get download directory (interactive)
              ├─ Create directory structure
              ├─ Generate scripts with paths
              └─ Save configuration
    ↓
[Subsequent Runs] → Load config → Main Menu
```

#### Directory Structure
```
bits-downloader/
├── bits-downloader.sh     [NEW] Main TUI application
├── .installed             [NEW] Installation marker
├── .config                [NEW] Configuration file
├── QUICKSTART.md          [NEW] Quick start guide
├── CHANGELOG.md           [NEW] This file
├── downloads/             [Customizable location]
├── torrents/
├── torrent_logs/
└── [all other scripts]
```

#### Color Scheme
- **Blue**: Headers, system info, BITS-DOWNLOADER logo
- **Cyan**: Section headers, important info
- **Green**: Success messages, active items
- **Yellow**: Warnings, attention items
- **Red**: Errors, exit options
- **White**: Primary text, menu options
- **Gray**: Secondary text, hints
- **Magenta**: Highlighted items

### Breaking Changes

None! The old scripts still work independently if needed.

### Migration Guide

**From v2.x to v3.0:**

No migration needed! Simply:
1. Run `./bits-downloader.sh`
2. If you already have torrents/downloads, they will be preserved
3. First run will ask for download directory - point to your existing one

**Note**: The old `install_torrents_manager.sh` is no longer needed but remains for compatibility.

### Known Issues

None at this time.

### Future Improvements

Planned for future releases:
- [ ] Configuration editor in TUI
- [ ] Automatic updates check
- [ ] Theme customization
- [ ] Torrent queue management
- [ ] Statistics and analytics dashboard
- [ ] Multiple download directory support
- [ ] Torrent categories/tags
- [ ] RSS feed support for automatic downloads

---

## Version 2.0 - Enhanced Monitoring (Previous)

### Monitor Improvements
- Accurate ETA parsing from transmission info
- Real-time peer count display
- Total file size vs downloaded amount tracking
- Individual download speeds per torrent
- Improved color-coded output

### File Management
- Automatic fallback deletion mechanism
- Manual cleanup when transmission fails
- Better error handling
- Permission issue detection

### Integrated Features
- Detailed torrent view from monitor
- Keyboard shortcuts
- Seamless interface transitions

---

## Version 1.0 - Initial Release

- Basic torrent manager functionality
- Transmission daemon integration
- Simple monitoring script
- Basic control panel
- Background service operation
