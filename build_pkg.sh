#!/bin/bash

# Package builder for qBittorrent Mullvad Autobind
# Creates a proper .pkg installer for macOS

set -e

echo "========================================="
echo "qBittorrent Mullvad Autobind PKG Builder"
echo "========================================="
echo ""

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check if main script exists
if [ ! -f "$SCRIPT_DIR/qbittorrent_mullvad_autobind.sh" ]; then
    echo -e "${RED}Error: qbittorrent_mullvad_autobind.sh not found${NC}"
    exit 1
fi

# Create build directories
BUILD_DIR="$SCRIPT_DIR/build"
PKG_ROOT="$BUILD_DIR/pkg_root"
SCRIPTS_DIR="$BUILD_DIR/pkg_scripts"

rm -rf "$PKG_ROOT" "$SCRIPTS_DIR"
mkdir -p "$PKG_ROOT"
mkdir -p "$SCRIPTS_DIR"

echo "Creating package payload..."

# Create the directory structure in the package root
mkdir -p "$PKG_ROOT/Library/Application Support/QBittorrentMullvadAutobind"
mkdir -p "$PKG_ROOT/Library/LaunchAgents"

# Copy the main script
cp "$SCRIPT_DIR/qbittorrent_mullvad_autobind.sh" "$PKG_ROOT/Library/Application Support/QBittorrentMullvadAutobind/"
chmod +x "$PKG_ROOT/Library/Application Support/QBittorrentMullvadAutobind/qbittorrent_mullvad_autobind.sh"

echo -e "${GREEN}✓ Created payload${NC}"

# Create postinstall script that runs after package installation
cat > "$SCRIPTS_DIR/postinstall" << 'POSTINSTALL_EOF'
#!/bin/bash

# Get the user who invoked the installer
CURRENT_USER="${USER}"
if [ -z "$CURRENT_USER" ] || [ "$CURRENT_USER" = "root" ]; then
    CURRENT_USER=$(stat -f "%Su" /dev/console)
fi

USER_HOME=$(eval echo "~$CURRENT_USER")

# Create user directories
mkdir -p "$USER_HOME/Scripts"

# Copy script to user's Scripts directory
cp "/Library/Application Support/QBittorrentMullvadAutobind/qbittorrent_mullvad_autobind.sh" "$USER_HOME/Scripts/"
chmod +x "$USER_HOME/Scripts/qbittorrent_mullvad_autobind.sh"
chown "$CURRENT_USER" "$USER_HOME/Scripts/qbittorrent_mullvad_autobind.sh"

# Create runner app
mkdir -p "$USER_HOME/Scripts/QBittorrentMullvadAutobindRunner.app/Contents/MacOS"

cat > "$USER_HOME/Scripts/QBittorrentMullvadAutobindRunner.app/Contents/Info.plist" << 'RUNNER_INFO_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>QBittorrentMullvadAutobindRunner</string>
    <key>CFBundleIdentifier</key>
    <string>com.dharmesh.qbittorrent.mullvad.autobind.runner</string>
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
    <string>1</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025 Dharmesh Tarapore. All rights reserved.</string>
</dict>
</plist>
RUNNER_INFO_EOF

cat > "$USER_HOME/Scripts/QBittorrentMullvadAutobindRunner.app/Contents/MacOS/QBittorrentMullvadAutobindRunner" << 'RUNNER_EXEC_EOF'
#!/bin/bash
exec "$HOME/Scripts/qbittorrent_mullvad_autobind.sh"
RUNNER_EXEC_EOF

chmod +x "$USER_HOME/Scripts/QBittorrentMullvadAutobindRunner.app/Contents/MacOS/QBittorrentMullvadAutobindRunner"
chown -R "$CURRENT_USER" "$USER_HOME/Scripts/QBittorrentMullvadAutobindRunner.app"

# Sign the runner app if possible
SIGNING_ID=$(su - "$CURRENT_USER" -c "security find-identity -v -p codesigning 2>/dev/null | grep 'Developer ID Application' | head -n 1 | awk -F'\"' '{print \$2}'")
if [ -z "$SIGNING_ID" ]; then
    SIGNING_ID=$(su - "$CURRENT_USER" -c "security find-identity -v -p codesigning 2>/dev/null | grep 'Apple Development' | head -n 1 | awk -F'\"' '{print \$2}'")
fi
if [ -n "$SIGNING_ID" ]; then
    su - "$CURRENT_USER" -c "codesign --force --deep --sign \"$SIGNING_ID\" \"$USER_HOME/Scripts/QBittorrentMullvadAutobindRunner.app\"" 2>/dev/null || true
fi

# Create LaunchAgent plist
cat > "$USER_HOME/Library/LaunchAgents/com.dharmesh.qbittorrent.mullvad.autobind.plist" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.dharmesh.qbittorrent.mullvad.autobind</string>
    <key>ProgramArguments</key>
    <array>
        <string>$USER_HOME/Scripts/QBittorrentMullvadAutobindRunner.app/Contents/MacOS/QBittorrentMullvadAutobindRunner</string>
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

chown "$CURRENT_USER" "$USER_HOME/Library/LaunchAgents/com.dharmesh.qbittorrent.mullvad.autobind.plist"

# Unload old agents
su - "$CURRENT_USER" -c "launchctl unload \"$USER_HOME/Library/LaunchAgents/com.dharmesh.qbittorrent.mullvad.autobind.plist\" 2>/dev/null" || true
su - "$CURRENT_USER" -c "launchctl unload \"$USER_HOME/Library/LaunchAgents/com.user.mullvad.qbittorrent.plist\" 2>/dev/null" || true

# Load the new agent
su - "$CURRENT_USER" -c "launchctl load \"$USER_HOME/Library/LaunchAgents/com.dharmesh.qbittorrent.mullvad.autobind.plist\""

# Run initial binding
su - "$CURRENT_USER" -c "\"$USER_HOME/Scripts/qbittorrent_mullvad_autobind.sh\"" 2>/dev/null || true

exit 0
POSTINSTALL_EOF

chmod +x "$SCRIPTS_DIR/postinstall"
echo -e "${GREEN}✓ Created postinstall script${NC}"

# Build the package
echo ""
echo "Building package..."

pkgbuild --root "$PKG_ROOT" \
    --scripts "$SCRIPTS_DIR" \
    --identifier "com.dharmesh.qbittorrent.mullvad.autobind" \
    --version "1.0.5" \
    --install-location "/" \
    "$BUILD_DIR/QBittorrentMullvadAutobind-component.pkg"

# Create a distribution XML for productbuild
cat > "$BUILD_DIR/distribution.xml" << 'DISTRIBUTION_EOF'
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="1">
    <title>qBittorrent Mullvad Autobind</title>
    <organization>com.dharmesh</organization>
    <domains enable_localSystem="true"/>
    <options customize="never" require-scripts="true" rootVolumeOnly="true" />
    <welcome file="welcome.html" mime-type="text/html" />
    <license file="license.txt" mime-type="text/plain" />
    <conclusion file="conclusion.html" mime-type="text/html" />
    <background file="background.png" mime-type="image/png" alignment="bottomleft" scaling="none"/>
    <choices-outline>
        <line choice="default">
            <line choice="com.dharmesh.qbittorrent.mullvad.autobind"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="com.dharmesh.qbittorrent.mullvad.autobind" visible="false">
        <pkg-ref id="com.dharmesh.qbittorrent.mullvad.autobind"/>
    </choice>
    <pkg-ref id="com.dharmesh.qbittorrent.mullvad.autobind" version="1.0.5" onConclusion="none">QBittorrentMullvadAutobind-component.pkg</pkg-ref>
</installer-gui-script>
DISTRIBUTION_EOF

# Create welcome text
cat > "$BUILD_DIR/welcome.html" << 'WELCOME_EOF'
<!DOCTYPE html>
<html>
<body>
<h1>qBittorrent Mullvad Autobind</h1>
<p>This installer will set up automatic binding of qBittorrent to your Mullvad VPN interface.</p>
<p><strong>Prerequisites:</strong></p>
<ul>
    <li>Mullvad VPN must be installed</li>
    <li>qBittorrent must be installed</li>
</ul>
<p>The installation will:</p>
<ul>
    <li>Install the autobind script to ~/Scripts/</li>
    <li>Create a background service that runs automatically</li>
    <li>Bind qBittorrent to your Mullvad interface immediately</li>
</ul>
</body>
</html>
WELCOME_EOF

# Create license text
cat > "$BUILD_DIR/license.txt" << 'LICENSE_EOF'
Copyright © 2025 Dharmesh Tarapore. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
LICENSE_EOF

# Create conclusion text
cat > "$BUILD_DIR/conclusion.html" << 'CONCLUSION_EOF'
<!DOCTYPE html>
<html>
<body>
<h1>Installation Complete!</h1>
<p>qBittorrent Mullvad Autobind has been successfully installed.</p>
<p>The background service is now running and will automatically bind qBittorrent to your Mullvad VPN interface whenever the network changes.</p>
<p><strong>What happens next:</strong></p>
<ul>
    <li>The service runs in the background automatically</li>
    <li>qBittorrent will be bound to your Mullvad interface</li>
    <li>The binding updates automatically when you reconnect to Mullvad</li>
</ul>
<p><strong>Troubleshooting:</strong></p>
<ul>
    <li>View logs: <code>cat ~/Library/Logs/qbittorrent_mullvad_autobind.log</code></li>
    <li>Test manually: <code>~/Scripts/qbittorrent_mullvad_autobind.sh</code></li>
</ul>
</body>
</html>
CONCLUSION_EOF

# Create a simple background (just a solid color placeholder)
# For a real background, you'd use an actual image
touch "$BUILD_DIR/background.png"

# Build the final product package
productbuild --distribution "$BUILD_DIR/distribution.xml" \
    --package-path "$BUILD_DIR" \
    --resources "$BUILD_DIR" \
    "$BUILD_DIR/QBittorrentMullvadAutobind.pkg"

echo -e "${GREEN}✓ Package created${NC}"

# Sign the package if Developer ID Installer certificate is available
INSTALLER_CERT=$(security find-identity -v -p basic | grep "Developer ID Installer" | head -n 1 | awk -F'"' '{print $2}')

if [ -n "$INSTALLER_CERT" ]; then
    echo ""
    echo "Signing package with: $INSTALLER_CERT"
    productsign --sign "$INSTALLER_CERT" \
        "$BUILD_DIR/QBittorrentMullvadAutobind.pkg" \
        "$BUILD_DIR/QBittorrentMullvadAutobind-signed.pkg"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Package signed successfully${NC}"
        rm "$BUILD_DIR/QBittorrentMullvadAutobind.pkg"
        mv "$BUILD_DIR/QBittorrentMullvadAutobind-signed.pkg" "$BUILD_DIR/QBittorrentMullvadAutobind.pkg"
    fi
else
    echo -e "${YELLOW}⚠ No Developer ID Installer certificate found${NC}"
    echo "Package is unsigned - users will see a warning"
fi

# Clean up intermediate files
rm -rf "$PKG_ROOT" "$SCRIPTS_DIR" "$BUILD_DIR/QBittorrentMullvadAutobind-component.pkg"
rm -f "$BUILD_DIR/distribution.xml" "$BUILD_DIR/welcome.html" "$BUILD_DIR/license.txt" "$BUILD_DIR/conclusion.html" "$BUILD_DIR/background.png"

echo ""
echo -e "${GREEN}Build complete!${NC}"
echo ""
echo "Output: $BUILD_DIR/QBittorrentMullvadAutobind.pkg"
echo ""
echo "Users can double-click the .pkg to install with a proper macOS installer UI."
echo ""

if [ -n "$INSTALLER_CERT" ]; then
    echo "To notarize the package:"
    echo "./notarize_pkg.sh"
fi
