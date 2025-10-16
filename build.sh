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
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025 Dharmesh Tarapore. All rights reserved.</string>
</dict>
</plist>
INFO_PLIST_EOF

# Copy the main script into the Resources folder
cp "$SCRIPT_DIR/qbittorrent_mullvad_autobind.sh" "$BUILD_DIR/QBittorrentMullvadAutobind.app/Contents/Resources/"

# Create the executable wrapper that references the bundled script
cat > "$BUILD_DIR/QBittorrentMullvadAutobind.app/Contents/MacOS/QBittorrentMullvadAutobind" << 'WRAPPER_EOF'
#!/bin/bash
# Get the path to the Resources folder
RESOURCES_DIR="$(dirname "$0")/../Resources"
exec "$RESOURCES_DIR/qbittorrent_mullvad_autobind.sh"
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
echo "The signed app bundle can be distributed to other users."
echo "They can install it by unzipping and copying to ~/Scripts/"
echo ""
