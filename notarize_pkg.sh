#!/bin/bash

# Notarization script for the .pkg installer

set -e

echo "====================================="
echo "PKG Notarizer"
echo "====================================="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BUILD_DIR="$SCRIPT_DIR/build"

# Load credentials from .env file
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo "Please create a .env file with:"
    echo "  APPLE_DEVELOPER_EMAIL=your@email.com"
    echo "  APPLE_APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx"
    echo "  APPLE_TEAM_ID=XXXXXXXXXX"
    exit 1
fi

source "$SCRIPT_DIR/.env"

if [ -z "$APPLE_DEVELOPER_EMAIL" ] || [ -z "$APPLE_APP_SPECIFIC_PASSWORD" ] || [ -z "$APPLE_TEAM_ID" ]; then
    echo -e "${RED}Error: Missing credentials in .env file${NC}"
    echo "Please ensure .env contains APPLE_DEVELOPER_EMAIL, APPLE_APP_SPECIFIC_PASSWORD, and APPLE_TEAM_ID"
    exit 1
fi

if [ ! -f "$BUILD_DIR/QBittorrentMullvadAutobind.pkg" ]; then
    echo -e "${RED}Error: Package not found. Run ./build_pkg.sh first.${NC}"
    exit 1
fi

echo "Using Apple ID: $APPLE_DEVELOPER_EMAIL"
echo ""
echo "Submitting package for notarization..."

xcrun notarytool submit "$BUILD_DIR/QBittorrentMullvadAutobind.pkg" \
    --apple-id "$APPLE_DEVELOPER_EMAIL" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Notarization successful!${NC}"
    echo ""
    echo "Stapling notarization ticket..."

    xcrun stapler staple "$BUILD_DIR/QBittorrentMullvadAutobind.pkg"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Complete!${NC}"
        echo ""
        echo "The notarized package is ready:"
        echo "  $BUILD_DIR/QBittorrentMullvadAutobind.pkg"
    fi
else
    echo -e "${RED}Notarization failed${NC}"
    exit 1
fi
