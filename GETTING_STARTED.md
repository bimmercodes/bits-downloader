# 🚀 Getting Started with BITS-DOWNLOADER

Quick start guide to get up and running in minutes!

---

## 📦 Installation

### Method 1: One-Line Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/bimmercodes/bits-downloader/main/install.sh | bash
```

Or with wget:

```bash
wget -qO- https://raw.githubusercontent.com/bimmercodes/bits-downloader/main/install.sh | bash
```

### Method 2: Manual Install

```bash
git clone https://github.com/bimmercodes/bits-downloader.git
cd bits-downloader
./bin/bits-downloader.sh
```

---

## 🎯 First Steps

### 1. Start the Application

```bash
cd bits-downloader
./bits
```

Or from bin directory:

```bash
./bin/bits-downloader.sh
```

### 2. First Run Setup

On first launch, you'll see an installation wizard that will:

- ✅ Check for `transmission-daemon`
- ✅ Install dependencies (requires sudo)
- ✅ Configure download directories
- ✅ Set up logging
- ✅ Create required folders

**Just follow the prompts!**

### 3. Main Menu

After setup, you'll see the main menu:

```
╔════════════════════════════════════════════╗
║      BITS-DOWNLOADER                       ║
║      by bimmercodes                        ║
╚════════════════════════════════════════════╝

● Torrent Manager: STOPPED

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

---

## 📝 Adding Your First Torrent

### Option A: Via Menu

1. Select `5` (Add Torrent)
2. Enter magnet link, URL, or file path
3. Press Enter

### Option B: Edit Torrent List

```bash
nano data/torrent_list.txt
```

Add torrents (one per line):
```
magnet:?xt=urn:btih:HASH&dn=NAME
http://example.com/file.torrent
```

### Option C: Drop Torrent Files

```bash
cp your-file.torrent torrents/
```

---

## 🎮 Basic Commands

### Start Downloading

1. Select `1` - Start Torrent Manager
2. Select `3` - Monitor Downloads
3. Watch your torrents download in real-time!

### View Progress

```bash
./bin/monitor_torrents.sh
```

Or use the fancy dashboard:

```bash
./ui/terminal_dashboard.sh
```

### Stop Everything

```bash
./bin/stop_torrents.sh
```

Or from menu: Select `2`

---

## 🎨 Terminal Dashboards

### Standard Dashboard

```bash
./ui/terminal_dashboard.sh
```

**Keyboard Shortcuts:**
- `q` - Quit
- `r` - Refresh
- `s` - Start torrents
- `t` - Stop torrents

### Demo Dashboard

```bash
./ui/demo_responsive.sh
```

**Features:**
- 🌈 Animated rainbow effects
- 📊 Real-time bar charts
- 📏 Responsive to terminal resize
- ✨ ~20 FPS smooth animations

**Try resizing your terminal while it runs!**

---

## 📁 Directory Structure

After installation:

```
bits-downloader/
├── bin/              # Executables
├── downloads/        # Your files go here!
├── torrents/         # Drop .torrent files here
├── logs/             # Application logs
└── data/             # Configuration
```

---

## 🔍 Common Tasks

### Check Download Status

```bash
transmission-remote -l
```

### View Logs

```bash
tail -f logs/torrent_manager.log
```

### See Completed Downloads

```bash
ls -lh downloads/
```

### Restart Manager

```bash
./bin/stop_torrents.sh && ./bin/start_torrents.sh
```

---

## 🆘 Troubleshooting

### "Transmission not running"

```bash
./bin/start_torrents.sh
```

### "Port 9091 in use"

```bash
# Stop system transmission
sudo systemctl stop transmission-daemon
sudo systemctl disable transmission-daemon

# Restart our manager
./bin/start_torrents.sh
```

### "Permission denied"

```bash
chmod +x bin/*.sh lib/*.sh ui/*.sh
```

### Scripts not found

```bash
# Make sure you're in the project directory
cd ~/bits-downloader

# Or use full paths
~/bits-downloader/bin/bits-downloader.sh
```

---

## 💡 Tips & Tricks

### 1. Quick Launch

Add to your `~/.bashrc`:

```bash
alias bits='~/bits-downloader/bits'
```

Then just run:

```bash
bits
```

### 2. Background Mode

The torrent manager runs in the background automatically.

Check if running:

```bash
pgrep -f torrent_manager
```

### 3. Monitor from Anywhere

Create an alias:

```bash
alias torrents='~/bits-downloader/ui/terminal_dashboard.sh'
```

### 4. Auto-Start on Boot

Add to crontab:

```bash
crontab -e
```

Add line:

```
@reboot cd ~/bits-downloader && ./bin/start_torrents.sh
```

---

## 📚 Next Steps

- 📖 Read the full [README.md](README.md) for detailed documentation
- 🔧 Check [docs/torrent_guide.md](docs/torrent_guide.md) for advanced usage
- 📝 View [CHANGELOG.md](docs/CHANGELOG.md) for version history
- 🌟 Star the repo on [GitHub](https://github.com/bimmercodes/bits-downloader)

---

## 🎉 You're Ready!

Start downloading and enjoy BITS-DOWNLOADER!

**Made with ❤️ by bimmercodes**

---

## 🔗 Quick Links

- **GitHub**: https://github.com/bimmercodes/bits-downloader
- **Issues**: https://github.com/bimmercodes/bits-downloader/issues
- **Transmission Docs**: https://github.com/transmission/transmission

---

Happy downloading! 🚀
