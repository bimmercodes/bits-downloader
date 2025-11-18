<p align="center">
  <img src="https://raw.githubusercontent.com/bimmercodes/bits-downloader/main/assets/logo.png" alt="bits-downloader logo" width="150">
</p>

<h1 align="center">BITS Downloader</h1>

<p align="center">
  <strong>Lightweight, dialog-driven BitTorrent manager for Linux servers.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/github/last-commit/bimmercodes/bits-downloader" alt="last commit">
  <img src="https://img.shields.io/github/license/bimmercodes/bits-downloader" alt="license">
</p>

BITS Downloader is a set of Bash scripts that provide a user-friendly interface for managing `transmission-daemon`. It's designed to be simple, efficient, and easy to use on a headless server.

## Features

- **TUI:** A dialog-based terminal user interface for easy management.
- **Live Dashboard:** A full-screen, real-time dashboard to monitor your torrents.
- **Automation:** A background service that automatically adds torrents from a file or a directory.
- **Flexible:** Add torrents via magnet links, URLs, or `.torrent` files.
- **Configurable:** Easily change the default directories for torrents, downloads, and logs.
- **Cross-distro:** Works on most Linux distributions (tested on Debian, Ubuntu, Fedora, and CentOS).

## Prerequisites

- Linux with Bash 5+
- `transmission-daemon` and `transmission-cli`
- `dialog`, `git`, and `curl` or `wget`
- `bc` (for byte formatting in dashboards)

## Installation

You can install BITS Downloader with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/bimmercodes/bits-downloader/main/install.sh | bash
```

This will clone the repository to `~/bits-downloader`, install the dependencies, and create a launcher at `~/bits`.

## Usage

To start the application, run the `bits` command in your terminal:

```bash
bits
```

This will open the main menu, where you can:

- Open the live dashboard
- Add a new torrent
- View torrent details
- Start/stop the torrent manager
- Resume/pause all torrents
- View current settings

### Adding Torrents

There are two ways to add torrents:

1.  **From the TUI:** Select the "Add a new torrent" option and paste a magnet link, URL, or file path.
2.  **Automatically:**
    - Add magnet links or URLs to the `data/torrent_list.txt` file (one per line).
    - Place `.torrent` files in the `torrents/` directory.

The background manager will automatically pick them up and start downloading.

## Configuration

The configuration is stored in the `.config` file in the project root. You can change the following settings:

- `TORRENT_DIR`: The directory where `.torrent` files are stored.
- `DOWNLOAD_DIR`: The directory where the downloaded files are stored.
- `LOG_DIR`: The directory where the logs are stored.
- `TORRENT_LIST`: The path to the file containing the list of torrents to download.

## Project Structure

```
.
├── bin/                # Main executable scripts
│   ├── bits-downloader.sh
│   ├── bits-manager.sh
│   └── ...
├── data/               # Data files
│   └── torrent_list.txt.example
├── downloads/          # Default download directory
├── install/            # Installation scripts for different distros
├── lib/                # Helper scripts and libraries
│   ├── config.sh
│   ├── transmission_api.sh
│   └── ...
├── logs/               # Log files
├── torrents/           # Default torrents directory
│   └── added/
├── ui/                 # User interface scripts
│   ├── dashboard.sh
│   └── ...
├── .gitignore
├── install.sh
├── README.md
└── uninstall.sh
```

## Contributing

Contributions are welcome! If you have any ideas, suggestions, or bug reports, please open an issue or submit a pull request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

<p align="center">
  <a href="#top">Back to top</a>
</p>