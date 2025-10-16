# Mullvad Autobind for qBittorrent

Automatically binds qBittorrent to Mullvad VPN's network interface on macOS. This ensures qBittorrent only uses the VPN connection and prevents any leaks if the VPN disconnects.

## Features

- Automatically detects and binds to Mullvad's active VPN interface
- Runs as a LaunchAgent that triggers on network changes
- Properly handles qBittorrent restarts to apply interface updates
- Signed app bundle for proper macOS identification
- Shows as "qBittorrent Mullvad Autobind" by Dharmesh Tarapore in System Settings

## Prerequisites

- macOS
- [Mullvad VPN](https://mullvad.net/) macOS desktop client
- [qBittorrent](https://www.qbittorrent.org/)

## Installation

### Quick Install (Recommended)

Clone this repo and run the installer:

```bash
git clone https://github.com/weirdindiankid/mullvad_autobind.git
cd mullvad_autobind
./install.sh
```

The installer will:
- Install the autobind script to `~/Scripts/`
- Create a signed app bundle (if available in the repo)
- Set up a LaunchAgent to run automatically on network changes
- Run the binding script immediately for first-time setup

After installation, the LaunchAgent will automatically detect Mullvad interface changes and update qBittorrent's binding as needed.

## For Developers

### Building a Signed App Bundle

If you have an Apple Developer account and want to create a signed, distributable version:

```bash
./build.sh
```

This will:
- Create a signed app bundle in `build/QBittorrentMullvadAutobind.app`
- Generate a distributable ZIP file `build/QBittorrentMullvadAutobind-signed.zip`
- Sign the bundle with your Apple Developer certificate

The signed bundle removes the "unidentified developer" warning in System Settings.

### Uninstalling

To uninstall:

```bash
./uninstall.sh
```

## How It Works

1. The LaunchAgent watches for network configuration changes
2. When triggered, it finds Mullvad's active VPN interface (e.g., `utun4`)
3. Force-kills qBittorrent to prevent config file conflicts
4. Updates `~/.config/qBittorrent/qBittorrent.ini` with the correct interface
5. Restarts qBittorrent with the new binding

## Troubleshooting

### View Logs

Check the logs to see what's happening:

```bash
cat ~/Library/Logs/qbittorrent_mullvad_autobind.log
```

### Manual Testing

Run the script manually to test:

```bash
~/Scripts/qbittorrent_mullvad_autobind.sh
```

### Check LaunchAgent Status

```bash
launchctl list | grep mullvad
```

### Reload LaunchAgent

If you need to reload the LaunchAgent:

```bash
launchctl unload ~/Library/LaunchAgents/com.dharmesh.qbittorrent.mullvad.autobind.plist
launchctl load ~/Library/LaunchAgents/com.dharmesh.qbittorrent.mullvad.autobind.plist
```
