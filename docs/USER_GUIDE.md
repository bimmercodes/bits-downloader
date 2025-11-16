# BITS Downloader - Complete User Guide

## Table of Contents

1. [Getting Started](#getting-started)
2. [Dashboard Overview](#dashboard-overview)
3. [Keyboard Shortcuts Reference](#keyboard-shortcuts-reference)
4. [Common Tasks](#common-tasks)
5. [Configuration](#configuration)
6. [Troubleshooting](#troubleshooting)
7. [Advanced Usage](#advanced-usage)

---

## Getting Started

### First Launch

1. Run the application:
   ```bash
   ~/bits  # if installed via installer
   # or
   cd ~/bits-downloader && ./bin/bits-downloader.sh
   ```

2. You'll see a splash screen, press any key to continue

3. Main menu appears with options:
   - **1** - Launch Dashboard
   - **2** - Start Transmission Daemon
   - **3** - Stop Transmission Daemon
   - **4** - Configuration
   - **q** - Quit

4. Press **2** to start the transmission daemon (first time)

5. Press **1** to launch the dashboard

### Adding Your First Torrent

1. In the dashboard, press **`a`** (add torrent)
2. Enter a magnet link, URL, or path to .torrent file
3. Press Enter
4. The torrent will appear in the list

---

## Dashboard Overview

### Main View Layout

```
╔════════════════════════════════════════╗  ← Header
║  BITS DOWNLOADER                       ║
╚════════════════════════════════════════╝

Torrents: 3 | Status: ● RUNNING | View: list  15:30:45  ← Status Bar

 ID   NAME                      SIZE    DONE    STATUS    ← Column Headers
 1    ubuntu-22.04...           3.6GB   100%    Seeding   ← Torrent List
 2    archlinux-2024...         850MB   45%     Downloading
 3    debian-12...              650MB   0%      Stopped

─────────────────────────────────────────────────────────  ← Separator
 j/k:Navigate | Enter:Details | s:Start | q:Quit          ← Help Bar
```

### Status Indicators

#### Transmission Status
- **● RUNNING** (green) - Daemon is active
- **● STOPPED** (red) - Daemon is not running

#### Torrent Status
- **Seeding** (green) - 100% complete, uploading to peers
- **Downloading** (yellow) - Actively downloading
- **Up & Down** (yellow) - Downloading and uploading simultaneously
- **Stopped** (red) - Torrent is paused
- **Idle** (red) - No activity

#### Visual Highlighting
- **Cyan background** - Currently selected torrent
- **Color-coded text** - Status-based coloring

---

## Keyboard Shortcuts Reference

### Navigation Keys

| Key | Alternative | Action | Description |
|-----|-------------|--------|-------------|
| `j` | `↓` | Move Down | Select next torrent |
| `k` | `↑` | Move Up | Select previous torrent |
| `g` | `Home` | Jump to Top | Select first torrent |
| `G` | `End` | Jump to Bottom | Select last torrent |
| `Enter` | - | View Details | Open detail view for selected torrent |
| `Esc` | - | Back to List | Return from detail view to list |

### Action Keys

| Key | Scope | Action | Confirmation Required |
|-----|-------|--------|----------------------|
| `s` | Single | Start Torrent | No |
| `p` | Single | Pause Torrent | No |
| `v` | Single | Verify Torrent | No |
| `d` | Single | Delete Torrent | Yes (y/N) |
| `a` | - | Add Torrent | Requires input |
| `r` | - | Refresh View | No |
| `S` | All | Start All Torrents | No |
| `P` | All | Pause All Torrents | No |
| `q` | - | Quit Dashboard | No |

### Detail View Shortcuts

When viewing torrent details (after pressing `Enter`):

| Key | Action |
|-----|--------|
| `Esc` or `Enter` | Return to list view |
| `s` | Start this torrent |
| `p` | Pause this torrent |
| `v` | Verify this torrent |
| `d` | Delete this torrent |
| `q` | Quit dashboard |

---

## Common Tasks

### Adding Torrents

#### Via Magnet Link
1. Press `a`
2. Paste magnet link: `magnet:?xt=urn:btih:...`
3. Press Enter

#### Via URL
1. Press `a`
2. Enter URL: `https://example.com/file.torrent`
3. Press Enter

#### Via Local File
1. Press `a`
2. Enter path: `/path/to/file.torrent`
3. Press Enter

### Managing Torrents

#### Starting a Torrent
1. Navigate to torrent with `j/k`
2. Press `s`

#### Pausing a Torrent
1. Navigate to torrent with `j/k`
2. Press `p`

#### Deleting a Torrent
1. Navigate to torrent with `j/k`
2. Press `d`
3. Type `y` to confirm or `n` to cancel

#### Verifying a Torrent
1. Navigate to torrent with `j/k`
2. Press `v`
(Useful if download was interrupted or you suspect corruption)

### Viewing Details

1. Navigate to torrent with `j/k`
2. Press `Enter`
3. View comprehensive information:
   - Full name
   - Current state
   - Progress percentage
   - Total size and downloaded amount
   - Download/upload speeds
   - Estimated time remaining
   - Seed ratio
   - Number of connected peers
   - Download location

### Bulk Operations

#### Start All Torrents
- Press `Shift+S` (capital S)

#### Pause All Torrents
- Press `Shift+P` (capital P)

---

## Configuration

### Configuration File

Location: `$INSTALL_DIR/.config`

```bash
TORRENT_DIR="/path/to/bits-downloader/torrents"
DOWNLOAD_DIR="/path/to/bits-downloader/downloads"
LOG_DIR="/path/to/bits-downloader/logs"
TORRENT_LIST="/path/to/bits-downloader/data/torrent_list.txt"
```

### Changing Download Directory

1. Exit dashboard (press `q`)
2. Edit config file:
   ```bash
   cd ~/bits-downloader
   nano .config
   ```
3. Change `DOWNLOAD_DIR` value
4. Save and exit
5. Restart application

### Viewing Current Configuration

1. From main menu, press `4`
2. Configuration paths are displayed
3. Press Enter to return to menu

---

## Troubleshooting

### Dashboard Issues

#### "No torrents available"
**Cause**: No torrents have been added yet, or transmission daemon not connected

**Solutions**:
1. Press `a` to add a torrent
2. Check if daemon is running (status bar shows "● RUNNING")
3. If stopped, exit dashboard and start daemon from main menu

#### "Transmission daemon not running"
**Cause**: Transmission daemon is not started

**Solutions**:
1. Exit dashboard (press `q`)
2. Select option 2 from main menu
3. Wait for daemon to start
4. Launch dashboard again (option 1)

#### Dashboard freezes
**Cause**: Terminal issue or stuck process

**Solutions**:
1. Try pressing `q` to quit
2. If unresponsive, press `Ctrl+C`
3. Kill process: `pkill -f dashboard.sh`
4. Restart application

#### Display is garbled
**Cause**: Terminal size too small or encoding issues

**Solutions**:
1. Resize terminal to at least 80x24
2. Try refreshing with `r`
3. Exit and restart dashboard
4. Check terminal encoding is UTF-8

### Keyboard Issues

#### Keys not responding
**Solutions**:
1. Ensure terminal window is focused
2. Try alternative keys (arrows instead of j/k)
3. Check if terminal has custom key bindings
4. Restart dashboard

#### Delete confirmation not appearing
**Solutions**:
1. Terminal may not support certain input modes
2. Use alternative method: exit dashboard and delete via transmission-remote

### Torrent Issues

#### Torrent stuck at 0%
**Possible causes**:
1. No seeds available
2. Network issues
3. Incorrect magnet link

**Solutions**:
1. Press `v` to verify torrent
2. Check torrent details (press `Enter`) for peer count
3. Try pausing (`p`) and starting (`s`) again
4. Check network connectivity

#### Very slow download
**Solutions**:
1. Check available seeds (view details)
2. Verify your internet connection
3. Check if other torrents are consuming bandwidth
4. Pause other torrents temporarily

#### Torrent missing after restart
**Cause**: Transmission daemon lost state

**Solutions**:
1. Check download directory for files
2. Re-add torrent (it will skip downloaded parts)
3. Check transmission logs in logs directory

---

## Advanced Usage

### Running in Background

#### Using screen
```bash
screen -S bits
~/bits
# Press Ctrl+A, then D to detach
# Reattach: screen -r bits
```

#### Using tmux
```bash
tmux new -s bits
~/bits
# Press Ctrl+B, then D to detach
# Reattach: tmux attach -t bits
```

### Custom Terminal Setup

#### For best colors
Use a modern terminal with true color support:
- iTerm2 (macOS)
- Alacritty (Cross-platform)
- Gnome Terminal (Linux)
- Windows Terminal (Windows with WSL)

#### Terminal size
Recommended: 120x30 or larger for comfortable viewing

### Integration with Other Tools

#### Watch download directory
```bash
watch -n 5 ls -lh ~/bits-downloader/downloads
```

#### Monitor logs
```bash
tail -f ~/bits-downloader/logs/transmission.log
```

### Performance Tuning

Edit transmission daemon settings in: `~/.config/transmission-daemon/settings.json`

Key settings:
- `peer-limit-global` - Maximum number of peers
- `speed-limit-down` - Download speed limit (KB/s)
- `speed-limit-up` - Upload speed limit (KB/s)

---

## Tips and Tricks

### Efficiency Tips

1. **Use keyboard exclusively** - Faster than mouse, true k9s style
2. **Master j/k navigation** - Quick up/down movement
3. **Learn the capital S/P** - Quick pause/resume all
4. **Use g/G** - Jump to top/bottom instantly
5. **Detail view for troubleshooting** - Press Enter on problematic torrents

### Workflow Suggestions

1. **Morning routine**:
   - Press `r` to refresh
   - Check completed torrents (green)
   - Add new torrents for the day

2. **Managing many torrents**:
   - Use `P` to pause all
   - Navigate with `j/k` to desired torrent
   - Press `s` to start only that one

3. **Verification**:
   - After power loss or system crash
   - Navigate to each torrent
   - Press `v` to verify integrity

---

## Quick Reference Card

```
┌─────────────────────────────────────────┐
│  BITS DOWNLOADER - Quick Reference      │
├─────────────────────────────────────────┤
│ NAVIGATION                              │
│  j/↓   - Next      k/↑    - Previous    │
│  g/Home - Top      G/End  - Bottom      │
│  Enter  - Details  Esc    - Back        │
├─────────────────────────────────────────┤
│ ACTIONS                                 │
│  s - Start    p - Pause    v - Verify   │
│  d - Delete   a - Add      r - Refresh  │
│  S - Start All    P - Pause All         │
│  q - Quit                               │
├─────────────────────────────────────────┤
│ STATUS COLORS                           │
│  🟢 Green  - Seeding/Complete           │
│  🟡 Yellow - Downloading                │
│  🔴 Red    - Stopped/Idle               │
│  🔵 Cyan   - Selected                   │
└─────────────────────────────────────────┘
```

---

## Support

- **Documentation**: See `docs/` directory
- **Issues**: GitHub Issues
- **Updates**: `git pull` in installation directory

---

**Made with ❤️ for terminal lovers**
