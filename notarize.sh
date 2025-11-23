#!/bin/bash

# Notarization script for qBittorrent Mullvad Autobind
# This submits the signed app to Apple for notarization

set -e

echo "====================================="
echo "qBittorrent Mullvad Autobind Notarizer"
echo "====================================="
echo ""

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BUILD_DIR="$SCRIPT_DIR/build"

# Check if zip exists
if [ ! -f "$BUILD_DIR/QBittorrentMullvadAutobind-signed.zip" ]; then
    echo -e "${RED}Error: Signed zip not found. Run ./build.sh first.${NC}"
    exit 1
fi

# Prompt for Apple ID
read -p "Enter your Apple ID email: " APPLE_ID

echo ""
echo "You need an app-specific password from https://appleid.apple.com"
echo "Go to Sign-In and Security → App-Specific Passwords → Generate Password"
echo ""
read -sp "Enter your app-specific password: " APP_PASSWORD
echo ""

echo ""
echo "Submitting to Apple for notarization..."
echo "This may take a few minutes..."

# Submit for notarization
xcrun notarytool submit "$BUILD_DIR/QBittorrentMullvadAutobind-signed.zip" \
    --apple-id "$APPLE_ID" \
    --password "$APP_PASSWORD" \
    --team-id "7KGHU7S762" \
    --wait

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Notarization successful!${NC}"
    echo ""
    echo "Stapling notarization ticket to app..."

    # Unzip, staple, and re-zip
    cd "$BUILD_DIR"
    rm -rf QBittorrentMullvadAutobind.app
    unzip -q QBittorrentMullvadAutobind-signed.zip

    xcrun stapler staple QBittorrentMullvadAutobind.app

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Stapling successful!${NC}"
        echo ""
        echo "Re-creating signed zip with notarized app..."
        rm QBittorrentMullvadAutobind-signed.zip
        zip -r QBittorrentMullvadAutobind-signed.zip QBittorrentMullvadAutobind.app

        echo -e "${GREEN}Complete!${NC}"
        echo ""
        echo "The notarized app is ready for distribution:"
        echo "  $BUILD_DIR/QBittorrentMullvadAutobind-signed.zip"
    else
        echo -e "${RED}Stapling failed${NC}"
        exit 1
    fi
else
    echo -e "${RED}Notarization failed${NC}"
    echo "Check the error message above for details."
    exit 1
fi
