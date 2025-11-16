# BITS-DOWNLOADER

Lightweight, dialog-driven BitTorrent manager built on `transmission-daemon`, with a live terminal dashboard, queue tools, and sensible defaults for Linux servers.

## Features
- Dialog menus for adding torrents, viewing details, and starting/stopping the manager
- Full-screen dashboard with scrolling, stats, and keyboard shortcuts
- Background torrent manager that auto-loads magnet links, URLs, and `.torrent` files
- Centralized logging (`logs/`) and status snapshots for quick inspection
- Cross-distro install script (apt/dnf/yum) plus manual setup path
- Single shared library set for colors, config, and Transmission helpers (DRY/SOLID)

## Requirements
- Linux with Bash 5+
- `transmission-daemon` and `transmission-cli`
- `dialog`, `git`, and `curl` or `wget`
- Optional: `bc` for byte formatting on some dashboards

## Installation

### One-liner (recommended)
```bash
curl -fsSL https://raw.githubusercontent.com/bimmercodes/bits-downloader/refs/heads/master/install.sh | bash
```
# or
```bash
wget -qO- https://raw.githubusercontent.com/bimmercodes/bits-downloader/refs/heads/master/install.sh | bash
```

The installer clones to `~/bits-downloader`, ensures dependencies, makes scripts executable, and drops a `~/bits` helper with an `alias bits=...` entry in your `~/.bashrc`.

### Manual
```bash
git clone https://github.com/bimmercodes/bits-downloader.git
cd bits-downloader
chmod +x bin/*.sh lib/*.sh ui/*.sh
./bin/bits-manager.sh
```

## Usage
- Launch the UI: `~/bits` (after installer) or `./bin/bits-manager.sh`
- Key actions from the menu: open live dashboard, add torrent, view details, start/stop/resume/pause all torrents, and view current paths/status.
- Quick scripts if you prefer CLI:
  - Start service: `./bin/start_torrents.sh`
  - Stop service: `./bin/stop_torrents.sh`
  - Classic monitor: `./bin/monitor_torrents.sh`

### Adding torrents
- From the menu: choose **Add a new torrent** and paste a magnet link, URL, or file path.
- Queue file: append to `data/torrent_list.txt` (one entry per line).
- Drop files: place `.torrent` files in `torrents/` (auto-moved to `torrents/added` after ingestion).

### Live dashboards
- Full-screen view: `./ui/terminal_dashboard.sh` (arrow keys to scroll, `r` refresh, `q` quit, `s` start manager, `t/p` pause, `u` resume).
- Dialog-free monitor: `./bin/monitor_torrents.sh` for a text summary with quick detail view.

## Configuration
- Settings live in `.config` at the project root:
  - `TORRENT_DIR` (default: `./torrents`)
  - `DOWNLOAD_DIR` (default: `./downloads`)
  - `LOG_DIR` (default: `./logs`)
  - `TORRENT_LIST` (default: `./data/torrent_list.txt`)
- Update values in `.config` and restart the manager. Directories are auto-created on start.

## Logs and troubleshooting
- Main manager log: `logs/torrent_manager.log`
- Transmission log: `logs/transmission.log`
- Recent completions: `logs/completed.log`
- Current status snapshot: `logs/current_status.txt`

Quick checks:
```bash
transmission-remote -l          # verify daemon connectivity
tail -f logs/torrent_manager.log # live manager log
chmod +x bin/*.sh lib/*.sh ui/*.sh # fix permissions if needed
```

## Uninstall
```bash
cd ~/bits-downloader
./uninstall.sh
```
Stops services, removes the install directory, cleans the `~/bits` helper and alias, and offers to keep your downloads. Transmission packages remain installed unless you remove them yourself.
