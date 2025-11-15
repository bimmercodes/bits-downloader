# 🚀 BITS-DOWNLOADER
<img width="1014" height="629" alt="image" src="https://github.com/user-attachments/assets/9030e136-87fc-4060-8304-b3094ee8bd62" />

**A powerful, feature-rich BitTorrent downloader with beautiful terminal UI**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/bash-5.0+-green.svg)](https://www.gnu.org/software/bash/)
[![Transmission](https://img.shields.io/badge/transmission-daemon-blue.svg)](https://transmissionbt.com/)

---

## ✨ Features

- 🎨 **Beautiful Terminal UI** - Multiple interfaces including full-screen responsive dashboard
- 📊 **Real-time Monitoring** - Watch your downloads progress in real-time
- 🔄 **Auto-resume** - Automatically resume incomplete downloads
- 📁 **Organized Downloads** - Clean directory structure with automatic organization
- 🎮 **Interactive Control** - Full control panel for managing torrents
- 📝 **Comprehensive Logging** - Detailed logs for all operations
- 🌈 **Responsive Design** - Terminal UI adapts to any screen size
- ⚡ **Fast & Efficient** - Powered by transmission-daemon
- 🏗️ **Clean Architecture** - Built with SOLID and DRY principles
- 🔧 **Easy Configuration** - Customizable download directories and settings

---

## 🚀 Quick Start

### One-Line Installation

```bash
curl -fsSL https://raw.githubusercontent.com/bimmercodes/bits-downloader/refs/heads/master/install.sh | bash
```

Or with wget:

```bash
wget -qO- https://raw.githubusercontent.com/bimmercodes/bits-downloader/refs/heads/master/install.sh | bash
```

That's it! The installer will:
1. ✅ Clone the repository
2. ✅ Install transmission-daemon (if needed)
3. ✅ Set up directory structure
4. ✅ Configure the application
5. ✅ Make scripts executable

---

## 📋 Prerequisites

- **OS**: Linux (Ubuntu/Debian recommended)
- **Bash**: Version 5.0 or higher
- **Packages**: `transmission-daemon`, `transmission-cli` (auto-installed)
- **Optional**: `bc` for enhanced terminal animations

---

## 📦 Manual Installation

If you prefer manual installation:

### 1. Clone the Repository

```bash
git clone https://github.com/bimmercodes/bits-downloader.git
cd bits-downloader
```

### 2. Run the Main Application

```bash
./bin/bits-downloader.sh
```

The first run will launch an installation wizard that will:
- Check for transmission-daemon
- Install required packages (with your permission)
- Configure directories
- Set up the environment

---

## 🎯 Getting Started

### Starting the Application

```bash
cd bits-downloader
./bin/bits-downloader.sh
```

### Main Menu Options

1. **Start Torrent Manager** - Launch the background torrent service
2. **Stop Torrent Manager** - Stop the torrent service
3. **Monitor Downloads** - Real-time download monitoring
4. **Control Panel** - Interactive torrent management
5. **Add Torrent** - Add new torrents (magnet links, URLs, files)
6. **View Logs** - Access system logs
7. **Settings** - View current configuration
0. **Exit** - Quit the application

### Adding Torrents

There are several ways to add torrents:

#### Method 1: Via Menu
1. Run `./bin/bits-downloader.sh`
2. Select option `5` (Add Torrent)
3. Enter magnet link, URL, or file path

#### Method 2: Edit Torrent List
Edit `data/torrent_list.txt` and add:
- Magnet links: `magnet:?xt=urn:btih:HASH&dn=NAME`
- HTTP URLs: `http://example.com/file.torrent`
- File paths: `/path/to/file.torrent`

```bash
nano data/torrent_list.txt
```

#### Method 3: Drop .torrent Files
Place `.torrent` files in the `torrents/` directory

---

## 🎨 Terminal Dashboards

### Standard Dashboard

```bash
./ui/terminal_dashboard.sh
```

Features:
- Real-time torrent status
- System statistics
- Network monitoring
- Download progress
- Keyboard controls (q=quit, r=refresh, s=start, t=stop)

### Demo Dashboard (Showcase)

```bash
./ui/demo_responsive.sh
```

An impressive animated demo showing:
- Full-screen responsive design
- Real-time size adaptation
- Animated visualizations
- Rainbow gradients
- ~20 FPS smooth animations

**Try resizing your terminal while running the demo!**

---

## 📁 Project Structure

```
bits-downloader/
├── bin/                          # Main executable scripts
│   ├── bits-downloader.sh        # Main TUI application
│   ├── start_torrents.sh         # Start torrent manager
│   ├── stop_torrents.sh          # Stop torrent manager
│   ├── monitor_torrents.sh       # Real-time monitor
│   └── torrent_control.sh        # Control panel
├── lib/                          # Shared libraries (SOLID & DRY)
│   ├── config.sh                 # Configuration loader
│   ├── utils.sh                  # Utilities (colors, logging)
│   ├── transmission_api.sh       # Transmission API wrapper
│   └── torrent_manager.sh        # Core torrent manager service
├── ui/                           # User interface scripts
│   ├── terminal_dashboard.sh     # Full-screen dashboard
│   └── demo_responsive.sh        # Demo showcase
├── docs/                         # Documentation
│   ├── QUICKSTART.md
│   ├── CHANGELOG.md
│   └── torrent_guide.md
├── data/                         # Data files
│   └── torrent_list.txt          # Torrent queue list
├── downloads/                    # Downloaded files (configurable)
├── torrents/                     # .torrent files
├── logs/                         # Application logs
├── .config                       # Application configuration
├── uninstall.sh                  # Uninstaller script
└── README.md                     # This file
```

### Code Architecture

The project follows **SOLID** and **DRY** principles:

- **Single Responsibility**: Each module has one clear purpose
- **Open/Closed**: Easy to extend without modifying existing code
- **Dependency Inversion**: All scripts depend on shared libraries
- **DRY (Don't Repeat Yourself)**: Common code centralized in libraries

---

## 🗑️ Uninstallation

### Quick Uninstall

```bash
cd bits-downloader
./uninstall.sh
```

The uninstaller will:
1. ✅ Stop all running torrents
2. ✅ Stop transmission-daemon
3. ✅ Remove the project directory
4. ⚠️  Downloaded files are kept by default (you'll be asked)

### Manual Uninstall

```bash
# Stop services
./bin/stop_torrents.sh

# Remove project
cd ..
rm -rf bits-downloader

# Optional: Remove transmission (if no longer needed)
sudo apt remove transmission-daemon transmission-cli
```

---

## 🔧 Configuration

Configuration is stored in `.config` at the project root:

```bash
cat .config
```

Default directories:
- **Downloads**: `./downloads/`
- **Torrents**: `./torrents/`
- **Logs**: `./logs/`
- **Data**: `./data/`

To reconfigure, remove `.installed` and restart:

```bash
rm .installed
./bin/bits-downloader.sh
```

---

## 📊 Monitoring & Logs

### View Logs

From the main menu, select option `6` or directly:

```bash
# Main log
less logs/torrent_manager.log

# Transmission log
less logs/transmission.log

# Completed downloads
less logs/completed.log

# Current status
cat logs/current_status.txt
```

### Real-time Monitoring

```bash
# Watch logs in real-time
tail -f logs/torrent_manager.log

# Monitor with the dashboard
./ui/terminal_dashboard.sh
```

---

## 🎮 Keyboard Shortcuts

### Terminal Dashboard
- `q` / `Q` - Quit
- `r` / `R` - Refresh
- `s` / `S` - Start torrent manager
- `t` / `T` - Stop all torrents
- `p` / `P` - Pause all torrents
- `u` / `U` - Resume all torrents

### Monitor View
- `Ctrl+C` - Exit
- `d` + ID - Show detailed info

---

## 🔍 Troubleshooting

### Transmission not starting

```bash
# Check if transmission is installed
which transmission-daemon

# Check if port 9091 is in use
sudo netstat -tlnp | grep 9091

# Stop existing transmission
transmission-daemon --stop
```

### Permission issues

```bash
# Make scripts executable
chmod +x bin/*.sh lib/*.sh ui/*.sh

# Check directory permissions
ls -la downloads/ torrents/ logs/
```

### No torrents downloading

```bash
# Check daemon status
transmission-remote -l

# Check torrent list
cat data/torrent_list.txt

# Restart manager
./bin/stop_torrents.sh
./bin/start_torrents.sh
```

---

## 🌐 Advanced Usage

### Custom Download Directory

During installation wizard, specify custom path when prompted:

```
Download directory [press Enter for default]: /mnt/storage/downloads
```

### Background Operation

The torrent manager runs as a background service:

```bash
# Start in background
./bin/start_torrents.sh

# Check if running
pgrep -f torrent_manager

# View background logs
tail -f logs/nohup.log
```

### Add Torrents via Command Line

```bash
# Direct to transmission
transmission-remote -a "magnet:?xt=urn:btih:HASH"

# Add to queue (for auto-start)
echo "magnet:?xt=urn:btih:HASH" >> data/torrent_list.txt
```

---

## 🤝 Contributing

Contributions are welcome! Feel free to:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

---

## 📄 License

MIT License - see LICENSE file for details

---

## 👨‍💻 Author

**bimmercodes**

- GitHub: [@bimmercodes](https://github.com/bimmercodes)
- Repository: [bits-downloader](https://github.com/bimmercodes/bits-downloader)

---

## 🌟 Show Your Support

If you find this project useful, please give it a ⭐️ on GitHub!

---

## 📝 Changelog

See [CHANGELOG.md](docs/CHANGELOG.md) for version history and updates.

---

## 🔗 Links

- [Transmission Documentation](https://github.com/transmission/transmission)
- [BitTorrent Protocol](https://www.bittorrent.org/beps/bep_0003.html)
- [Bash Scripting Guide](https://www.gnu.org/software/bash/manual/)

---

## 🎬 Demo

Want to see it in action? Run the responsive demo:

```bash
./ui/demo_responsive.sh
```

<img width="1394" height="687" alt="image" src="https://github.com/user-attachments/assets/1e580d9c-05b3-4411-b112-30c03f07c221" />

Try resizing your terminal to see the responsive design magic! ✨

---

**Made with ❤️ by bimmercodes**
