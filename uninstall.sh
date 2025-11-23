#!/bin/bash

# Uninstall script for qBittorrent Mullvad Autobind
# This script removes all components installed by install.sh

echo "==========================================="
echo "qBittorrent Mullvad Autobind Uninstaller"
echo "==========================================="
echo ""

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Track if anything was actually uninstalled
UNINSTALLED_SOMETHING=false

# Function to safely remove a file
remove_file() {
    local file="$1"
    local description="$2"

    if [ -f "$file" ]; then
        rm -f "$file"
        echo -e "${GREEN}Removed $description${NC}"
        UNINSTALLED_SOMETHING=true
    fi
}

# Function to safely remove a directory
remove_dir() {
    local dir="$1"
    local description="$2"

    if [ -d "$dir" ]; then
        rm -rf "$dir"
        echo -e "${GREEN}Removed $description${NC}"
        UNINSTALLED_SOMETHING=true
    fi
}

# Function to safely unload a LaunchAgent
unload_agent() {
    local label="$1"
    local plist="$2"
    local description="$3"

    if launchctl list | grep -q "$label"; then
        echo "Stopping and unloading $description..."
        launchctl stop "$label" 2>/dev/null || true
        launchctl unload "$plist" 2>/dev/null || true
        echo -e "${GREEN}Unloaded $description${NC}"
        UNINSTALLED_SOMETHING=true
    fi
}

echo "Checking for installed components..."
echo ""

# Unload and remove old LaunchAgent (from previous versions)
unload_agent "com.user.mullvad.qbittorrent" \
    "$HOME/Library/LaunchAgents/com.user.mullvad.qbittorrent.plist" \
    "old LaunchAgent"

remove_file "$HOME/Library/LaunchAgents/com.user.mullvad.qbittorrent.plist" \
    "old LaunchAgent plist"

# Unload and remove current LaunchAgent
unload_agent "com.mullvad.qbittorrent.autobind" \
    "$HOME/Library/LaunchAgents/com.mullvad.qbittorrent.autobind.plist" \
    "LaunchAgent"

remove_file "$HOME/Library/LaunchAgents/com.mullvad.qbittorrent.autobind.plist" \
    "LaunchAgent plist"

# Remove the autobind script
remove_file "$HOME/Scripts/qbittorrent_mullvad_autobind.sh" \
    "autobind script"

# Remove the app bundle
remove_dir "$HOME/Scripts/QBittorrentMullvadAutobind.app" \
    "app bundle"

# Remove log files
echo ""
echo "Checking for log files..."
LOG_FILES_FOUND=false
for log in "$HOME/Library/Logs/qbittorrent_mullvad_autobind.log"* \
           "/tmp/qbittorrent_mullvad_error.log" \
           "/tmp/qbittorrent_mullvad_output.log"; do
    if [ -f "$log" ]; then
        rm -f "$log"
        echo -e "${GREEN}Removed log file: $(basename "$log")${NC}"
        LOG_FILES_FOUND=true
        UNINSTALLED_SOMETHING=true
    fi
done

if [ "$LOG_FILES_FOUND" = false ]; then
    echo "No log files found."
fi

# Remove backup config files
echo ""
echo "Checking for qBittorrent config backups..."
BACKUP_FILES_FOUND=false
for backup in "$HOME/.config/qBittorrent/qBittorrent.ini.bak"*; do
    if [ -f "$backup" ]; then
        echo -e "${YELLOW}Found backup: $backup${NC}"
        read -p "Do you want to remove this backup? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -f "$backup"
            echo -e "${GREEN}Removed backup file${NC}"
            UNINSTALLED_SOMETHING=true
        fi
        BACKUP_FILES_FOUND=true
    fi
done

if [ "$BACKUP_FILES_FOUND" = false ]; then
    echo "No backup files found."
fi

echo ""
if [ "$UNINSTALLED_SOMETHING" = true ]; then
    echo -e "${GREEN}Uninstallation complete!${NC}"
    echo ""
    echo "Note: Your qBittorrent configuration file was NOT modified."
    echo "If you want to reset the interface binding in qBittorrent,"
    echo "open qBittorrent → Preferences → Advanced → Network Interface"
    echo "and change it to your preferred setting."
else
    echo -e "${YELLOW}No installed components found.${NC}"
    echo "The application may not have been installed, or was already uninstalled."
fi

echo ""
