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

if [ ! -f "$BUILD_DIR/QBittorrentMullvadAutobind.pkg" ]; then
    echo -e "${RED}Error: Package not found. Run ./build_pkg.sh first.${NC}"
    exit 1
fi

read -p "Enter your Apple ID email: " APPLE_ID
echo ""
read -sp "Enter your app-specific password: " APP_PASSWORD
echo ""

echo ""
echo "Submitting package for notarization..."

xcrun notarytool submit "$BUILD_DIR/QBittorrentMullvadAutobind.pkg" \
    --apple-id "$APPLE_ID" \
    --password "$APP_PASSWORD" \
    --team-id "7KGHU7S762" \
    --wait

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Notarization successful!${NC}"
    echo ""
    echo "Stapling notarization ticket..."

    xcrun stapler staple "$BUILD_DIR/QBittorrentMullvadAutobind.pkg"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Complete!${NC}"
        echo ""
        echo "The notarized package is ready:"
        echo "  $BUILD_DIR/QBittorrentMullvadAutobind.pkg"
    fi
else
    echo -e "${RED}✗ Notarization failed${NC}"
    exit 1
fi
