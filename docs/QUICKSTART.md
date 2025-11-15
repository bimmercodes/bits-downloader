# BITS-DOWNLOADER - Quick Start Guide

## First Time Setup (30 seconds)

1. **Run the application:**
   ```bash
   ./bits-downloader.sh
   ```

2. **Follow the installation wizard:**
   - It will check for transmission-daemon (installs if needed)
   - Choose your download directory (or press Enter for default)
   - Wait for setup to complete

3. **You're done!** The main menu will appear.

## Daily Use

**Starting the application:**
```bash
./bits-downloader.sh
```

**Most common workflow:**

1. **Start Torrent Manager** (option 1)
   - This starts the background service

2. **Add Torrent** (option 5)
   - Paste your magnet link or URL
   - Press Enter

3. **Monitor Downloads** (option 3)
   - Watch your downloads in real-time
   - Press Ctrl+C twice to exit

4. **Stop Torrent Manager** (option 2) when done
   - Safely stops all services

## Adding Multiple Torrents

**Option A: Through TUI**
- Use option 5 repeatedly to add torrents one by one

**Option B: Bulk add via file**
1. Edit `torrent_list.txt`
2. Add your magnet links (one per line)
3. Start the manager (option 1)
4. All torrents will be added automatically

## Tips

- The manager runs in the background - you can close the terminal
- Downloads survive SSH disconnects
- Use option 3 (Monitor) to check progress anytime
- Use option 4 (Control Panel) for advanced management

## Keyboard Shortcuts in Monitor

- **Ctrl+C twice**: Exit monitor
- **Ctrl+C + d**: View detailed torrent info (enter ID)

## Common Issues

**"Transmission-daemon is not running"**
→ Start it first with option 1 in main menu

**"Torrent manager is already running"**
→ This is normal - your torrents are downloading!

**Want to see what's downloading?**
→ Use option 3 (Monitor Downloads)

## File Locations

- **Downloads**: `downloads/` (or your custom directory)
- **Torrents**: `torrents/` (drop .torrent files here)
- **Logs**: `torrent_logs/`
- **Configuration**: `.config` (auto-generated)

## Need Help?

- Check the full README.md for detailed documentation
- View logs with option 6 in the main menu
- Check settings with option 7 in the main menu

---

**That's it! Enjoy your torrents!** 🏎️
