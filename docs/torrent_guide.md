TORRENT MANAGER - QUICK REFERENCE
==================================

INSTALLATION:
-------------
1. Copy install_torrent_manager.sh to your Ubuntu VM
2. chmod +x install_torrent_manager.sh
3. ./install_torrent_manager.sh

USAGE:
------
Start Service:     ./start_torrents.sh
Monitor Progress:  ./monitor_torrents.sh  (real-time view with detailed stats)
Control Panel:     ./torrent_control.sh   (interactive menu)
Stop Service:      ./stop_torrents.sh

MONITOR FEATURES:
-----------------
The enhanced monitor now shows:
- Real-time download/upload speeds
- Progress percentage for each torrent
- Downloaded size vs Total size (e.g., 2.5 GB / 5.0 GB)
- ETA (Estimated Time of Arrival)
- Number of connected peers
- Individual download speed per torrent
- Detailed view: Press Ctrl+C then 'd' and enter torrent ID

ADD TORRENTS:
-------------
Method 1: Edit ~/torrent_list.txt (add magnet links/URLs)
Method 2: Place .torrent files in ~/torrents/
Method 3: transmission-remote -a "magnet:?xt=..."
Method 4: Use ./torrent_control.sh menu

COMMANDS:
---------
List all:          transmission-remote -l
Pause torrent:     transmission-remote -t ID -S
Resume torrent:    transmission-remote -t ID -s
Remove torrent:    transmission-remote -t ID -r
Remove + delete:   transmission-remote -t ID --remove-and-delete
                   (torrent_control.sh now has improved file deletion with fallback)
Set speed limit:   transmission-remote -d 500  (500 KB/s download)
                   transmission-remote -u 100  (100 KB/s upload)
Detailed info:     transmission-remote -t ID -i
                   (or use monitor_torrents.sh: Ctrl+C then 'd')

LOGS:
-----
Main log:          tail -f ~/torrent_logs/torrent_manager.log
Completed:         cat ~/torrent_logs/completed.log
Current status:    cat ~/torrent_logs/current_status.txt
Transmission log:  tail -f ~/torrent_logs/transmission.log

DIRECTORIES:
------------
Downloads:         ~/downloads/
Incomplete:        ~/downloads/.incomplete/
Torrent files:     ~/torrents/
Logs:              ~/torrent_logs/

PERSISTENCE:
------------
- Service runs with nohup (survives SSH logout)
- To reconnect after logout: ssh back in and run ./monitor_torrents.sh
- Service auto-starts all torrents on launch
- Completed torrents are auto-removed from queue

TROUBLESHOOTING:
----------------
Check if running:  pgrep -f torrent_manager.sh
Check daemon:      transmission-remote -l
View errors:       tail ~/torrent_logs/torrent_manager.log
Restart:           ./stop_torrents.sh && ./start_torrents.sh

RECENT IMPROVEMENTS:
--------------------
✓ Enhanced monitor display with detailed statistics:
  - Shows ETA properly parsed from transmission info
  - Displays peer count for active torrents
  - Shows total file size and downloaded amount
  - Individual download speeds per torrent
  - Color-coded output for better readability

✓ Improved torrent deletion in torrent_control.sh:
  - Automatic fallback if transmission can't delete files
  - Manual cleanup ensures files are properly removed
  - Better error messages and user feedback

✓ Integrated detailed view into monitor:
  - Press Ctrl+C then 'd' to view full torrent details
  - No need to switch to control panel for quick info
  - Returns to monitoring after viewing details
