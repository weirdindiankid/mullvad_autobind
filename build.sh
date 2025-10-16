#!/bin/bash

# Build script for qBittorrent Mullvad Autobind
# This script creates a signed, distributable app bundle
# Created by Dharmesh Tarapore

set -e

echo "====================================="
echo "qBittorrent Mullvad Autobind Builder"
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

# Check if the main script exists
if [ ! -f "$SCRIPT_DIR/qbittorrent_mullvad_autobind.sh" ]; then
    echo -e "${RED}Error: qbittorrent_mullvad_autobind.sh not found in $SCRIPT_DIR${NC}"
    exit 1
fi

# Create build directory
BUILD_DIR="$SCRIPT_DIR/build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "Creating app bundle in build directory..."
mkdir -p "$BUILD_DIR/QBittorrentMullvadAutobind.app/Contents/MacOS"
mkdir -p "$BUILD_DIR/QBittorrentMullvadAutobind.app/Contents/Resources"

# Create Info.plist for the app bundle
cat > "$BUILD_DIR/QBittorrentMullvadAutobind.app/Contents/Info.plist" << 'INFO_PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>QBittorrentMullvadAutobind</string>
    <key>CFBundleIdentifier</key>
    <string>com.dharmesh.qbittorrent.mullvad.autobind</string>
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
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025 Dharmesh Tarapore. All rights reserved.</string>
</dict>
</plist>
INFO_PLIST_EOF

# Copy the main script into the Resources folder
cp "$SCRIPT_DIR/qbittorrent_mullvad_autobind.sh" "$BUILD_DIR/QBittorrentMullvadAutobind.app/Contents/Resources/"

# Create an installer wrapper that does full setup
cat > "$BUILD_DIR/QBittorrentMullvadAutobind.app/Contents/MacOS/QBittorrentMullvadAutobind" << 'WRAPPER_EOF'
#!/bin/bash

# Installer for qBittorrent Mullvad Autobind
# This app bundle performs a complete installation when double-clicked

# Get the path to the Resources folder
RESOURCES_DIR="$(dirname "$0")/../Resources"

# Show a user-friendly dialog
osascript <<EOD
display dialog "Welcome to qBittorrent Mullvad Autobind Installer

This will:
• Install the autobind script to ~/Scripts/
• Create a background LaunchAgent
• Run the initial binding

Prerequisites:
• Mullvad VPN must be installed
• qBittorrent must be installed

Continue with installation?" buttons {"Cancel", "Install"} default button "Install" with icon note with title "qBittorrent Mullvad Autobind"
EOD

if [ $? -ne 0 ]; then
    exit 0
fi

# Create necessary directories
mkdir -p "$HOME/Scripts"
mkdir -p "$HOME/Library/LaunchAgents"
mkdir -p "$HOME/Library/Logs"

# Copy the script to ~/Scripts
cp "$RESOURCES_DIR/qbittorrent_mullvad_autobind.sh" "$HOME/Scripts/"
chmod +x "$HOME/Scripts/qbittorrent_mullvad_autobind.sh"

# Copy this entire app bundle to ~/Scripts for the LaunchAgent to reference
SELF_PATH="$(cd "$(dirname "$0")/../.." && pwd)/$(basename "$(dirname "$0")/../..")"
if [ "$SELF_PATH" != "$HOME/Scripts/QBittorrentMullvadAutobind.app" ]; then
    cp -R "$SELF_PATH" "$HOME/Scripts/"
fi

# Create the LaunchAgent plist
cat > "$HOME/Library/LaunchAgents/com.dharmesh.qbittorrent.mullvad.autobind.plist" << 'PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.dharmesh.qbittorrent.mullvad.autobind</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>~/Scripts/qbittorrent_mullvad_autobind.sh</string>
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

# Unload existing agent if present
launchctl unload "$HOME/Library/LaunchAgents/com.dharmesh.qbittorrent.mullvad.autobind.plist" 2>/dev/null || true
launchctl unload "$HOME/Library/LaunchAgents/com.user.mullvad.qbittorrent.plist" 2>/dev/null || true

# Load the new agent
launchctl load "$HOME/Library/LaunchAgents/com.dharmesh.qbittorrent.mullvad.autobind.plist"

# Run the script once to do initial binding
if bash "$HOME/Scripts/qbittorrent_mullvad_autobind.sh" 2>/dev/null; then
    STATUS="Installation complete!

The autobind script has been installed and is now running in the background.

It will automatically update qBittorrent's interface binding whenever Mullvad reconnects."
else
    STATUS="Installation complete!

Note: Initial binding may have failed because Mullvad VPN is not connected.

The script will run automatically when you connect to Mullvad."
fi

osascript <<EOD
display dialog "$STATUS" buttons {"OK"} default button "OK" with icon note with title "Installation Complete"
EOD
WRAPPER_EOF

chmod +x "$BUILD_DIR/QBittorrentMullvadAutobind.app/Contents/MacOS/QBittorrentMullvadAutobind"
chmod +x "$BUILD_DIR/QBittorrentMullvadAutobind.app/Contents/Resources/qbittorrent_mullvad_autobind.sh"
echo -e "${GREEN}✓ Created app bundle${NC}"

# Check for code signing identity
echo ""
echo "Checking for code signing identity..."
SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Apple Development" | head -n 1 | awk -F'"' '{print $2}')

if [ -n "$SIGNING_IDENTITY" ]; then
    echo "Found signing identity: $SIGNING_IDENTITY"
    echo "Signing app bundle..."

    codesign --force --deep --sign "$SIGNING_IDENTITY" "$BUILD_DIR/QBittorrentMullvadAutobind.app"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ App bundle signed successfully${NC}"

        # Verify the signature
        echo ""
        echo "Verifying signature..."
        codesign -vvv --deep --strict "$BUILD_DIR/QBittorrentMullvadAutobind.app"

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Signature verified${NC}"
        fi
    else
        echo -e "${RED}✗ Code signing failed${NC}"
        exit 1
    fi
else
    echo -e "${RED}Error: No code signing identity found${NC}"
    echo "Please ensure you have a valid Apple Developer certificate installed"
    exit 1
fi

# Create a distributable zip
echo ""
echo "Creating distributable package..."
cd "$BUILD_DIR"
zip -r "QBittorrentMullvadAutobind-signed.zip" QBittorrentMullvadAutobind.app
cd - > /dev/null

echo -e "${GREEN}✓ Created distributable package${NC}"

echo ""
echo -e "${GREEN}Build complete!${NC}"
echo ""
echo "Output files:"
echo "  • App bundle: $BUILD_DIR/QBittorrentMullvadAutobind.app"
echo "  • Distributable: $BUILD_DIR/QBittorrentMullvadAutobind-signed.zip"
echo ""
echo "The signed app bundle is now a complete installer."
echo "Users can simply double-click the .app to install everything!"
echo ""
