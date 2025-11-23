#!/bin/bash

# Install script for qBittorrent Mullvad Autobind
# This script sets up automatic binding of qBittorrent to Mullvad VPN interface on macOS

set -e

echo "====================================="
echo "qBittorrent Mullvad Autobind Installer"
echo "====================================="
echo ""

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}Error: This script is only for macOS${NC}"
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Create necessary directories
echo "Creating directories..."
mkdir -p "$HOME/Scripts"
mkdir -p "$HOME/Library/LaunchAgents"
mkdir -p "$HOME/Library/Logs"

# Check if a pre-built signed app bundle exists
if [ -d "$SCRIPT_DIR/build/QBittorrentMullvadAutobind.app" ]; then
    echo "Found pre-built signed app bundle, installing..."
    cp -R "$SCRIPT_DIR/build/QBittorrentMullvadAutobind.app" "$HOME/Scripts/"
    echo -e "${GREEN}Installed pre-built signed app bundle${NC}"

    # Also copy the script separately for manual testing
    if [ -f "$SCRIPT_DIR/qbittorrent_mullvad_autobind.sh" ]; then
        cp "$SCRIPT_DIR/qbittorrent_mullvad_autobind.sh" "$HOME/Scripts/qbittorrent_mullvad_autobind.sh"
        chmod +x "$HOME/Scripts/qbittorrent_mullvad_autobind.sh"
    fi
else
    # No pre-built bundle, create unsigned app bundle from scratch
    echo "No pre-built bundle found, creating unsigned app bundle..."

    # Copy the autobind script from the repo
    echo "Installing autobind script..."
    if [ -f "$SCRIPT_DIR/qbittorrent_mullvad_autobind.sh" ]; then
        cp "$SCRIPT_DIR/qbittorrent_mullvad_autobind.sh" "$HOME/Scripts/qbittorrent_mullvad_autobind.sh"
        chmod +x "$HOME/Scripts/qbittorrent_mullvad_autobind.sh"
        echo -e "${GREEN}Installed autobind script${NC}"
    else
        echo -e "${RED}Error: qbittorrent_mullvad_autobind.sh not found in $SCRIPT_DIR${NC}"
        exit 1
    fi

    # Create the app bundle structure
    echo "Creating app bundle..."
    mkdir -p "$HOME/Scripts/QBittorrentMullvadAutobind.app/Contents/MacOS"

    # Create Info.plist for the app bundle
    cat > "$HOME/Scripts/QBittorrentMullvadAutobind.app/Contents/Info.plist" << 'INFO_PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>QBittorrentMullvadAutobind</string>
    <key>CFBundleIdentifier</key>
    <string>com.mullvad.qbittorrent.autobind</string>
    <key>CFBundleName</key>
    <string>qBittorrent Mullvad Autobind</string>
    <key>CFBundleDisplayName</key>
    <string>qBittorrent Mullvad Autobind</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025. All rights reserved.</string>
</dict>
</plist>
INFO_PLIST_EOF

# Create the executable wrapper
cat > "$HOME/Scripts/QBittorrentMullvadAutobind.app/Contents/MacOS/QBittorrentMullvadAutobind" << 'WRAPPER_EOF'
#!/bin/bash
exec ~/Scripts/qbittorrent_mullvad_autobind.sh
WRAPPER_EOF

    chmod +x "$HOME/Scripts/QBittorrentMullvadAutobind.app/Contents/MacOS/QBittorrentMullvadAutobind"
    echo -e "${GREEN}Created unsigned app bundle${NC}"
    echo -e "${YELLOW}WARNING: App will show as 'unidentified developer' in System Settings${NC}"
fi

# Create the Launch Agent plist
echo "Creating Launch Agent..."
cat > "$HOME/Library/LaunchAgents/com.mullvad.qbittorrent.autobind.plist" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.mullvad.qbittorrent.autobind</string>
    <key>ProgramArguments</key>
    <array>
        <string>$HOME/Scripts/QBittorrentMullvadAutobind.app/Contents/MacOS/QBittorrentMullvadAutobind</string>
    </array>
    <key>ProcessType</key>
    <string>Background</string>
    <key>RunAtLoad</key>
    <true/>
    <key>WatchPaths</key>
    <array>
        <string>/var/run/resolv.conf</string>
        <string>/Library/Preferences/SystemConfiguration/NetworkInterfaces.plist</string>
    </array>
    <key>StandardErrorPath</key>
    <string>/tmp/qbittorrent_mullvad_error.log</string>
    <key>StandardOutPath</key>
    <string>/tmp/qbittorrent_mullvad_output.log</string>
</dict>
</plist>
PLIST_EOF

echo -e "${GREEN}Created Launch Agent plist${NC}"

# Check if qBittorrent config exists
if [ ! -f "$HOME/.config/qBittorrent/qBittorrent.ini" ]; then
    echo ""
    echo -e "${YELLOW}Warning: qBittorrent config file not found at ~/.config/qBittorrent/qBittorrent.ini${NC}"
    echo -e "${YELLOW}Please open qBittorrent and go to Preferences at least once to create the config file.${NC}"
    echo ""
fi

# Unload existing launch agent if it exists (try both old and new labels)
if launchctl list | grep -q "com.user.mullvad.qbittorrent"; then
    echo "Unloading old Launch Agent..."
    launchctl unload "$HOME/Library/LaunchAgents/com.user.mullvad.qbittorrent.plist" 2>/dev/null || true
    rm -f "$HOME/Library/LaunchAgents/com.user.mullvad.qbittorrent.plist"
fi

if launchctl list | grep -q "com.mullvad.qbittorrent.autobind"; then
    echo "Unloading existing Launch Agent..."
    launchctl unload "$HOME/Library/LaunchAgents/com.mullvad.qbittorrent.autobind.plist" 2>/dev/null || true
fi

# Load the launch agent
echo "Loading Launch Agent..."
launchctl load "$HOME/Library/LaunchAgents/com.mullvad.qbittorrent.autobind.plist"

# Verify it's loaded
if launchctl list | grep -q "com.mullvad.qbittorrent.autobind"; then
    echo -e "${GREEN}Launch Agent loaded successfully${NC}"
else
    echo -e "${RED}Failed to load Launch Agent${NC}"
    exit 1
fi

# Run the autobind script immediately for first-time setup
echo ""
echo "Running initial interface binding..."
if [ -f "$HOME/Scripts/qbittorrent_mullvad_autobind.sh" ]; then
    if bash "$HOME/Scripts/qbittorrent_mullvad_autobind.sh"; then
        echo -e "${GREEN}Initial binding completed successfully${NC}"
    else
        echo -e "${YELLOW}WARNING: Initial binding failed. This is normal if Mullvad VPN is not connected.${NC}"
        echo -e "${YELLOW}The script will run automatically when you connect to Mullvad.${NC}"
    fi
else
    echo -e "${YELLOW}WARNING: Could not find autobind script for initial run${NC}"
fi

echo ""
echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo "The autobind script will now run automatically whenever your network changes."
echo ""
echo "Useful commands:"
echo "  • Test manually: ~/Scripts/qbittorrent_mullvad_autobind.sh"
echo "  • View logs: cat ~/Library/Logs/qbittorrent_mullvad_autobind.log"
echo "  • Unload agent: launchctl unload ~/Library/LaunchAgents/com.mullvad.qbittorrent.autobind.plist"
echo "  • Reload agent: launchctl unload ~/Library/LaunchAgents/com.mullvad.qbittorrent.autobind.plist && launchctl load ~/Library/LaunchAgents/com.mullvad.qbittorrent.autobind.plist"
echo ""
