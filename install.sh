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

# Create necessary directories
echo "Creating directories..."
mkdir -p "$HOME/Scripts"
mkdir -p "$HOME/Library/LaunchAgents"
mkdir -p "$HOME/Library/Logs"

# Create the autobind script
echo "Creating autobind script..."
cat > "$HOME/Scripts/qbittorrent_mullvad_autobind.sh" << 'SCRIPT_EOF'
#!/bin/bash

# Script to autobind qBittorrent to Mullvad VPN interface on macOS

# Configuration
QBITTORRENT_CONFIG="$HOME/.config/qBittorrent/qBittorrent.ini"
LOG_FILE="$HOME/Library/Logs/qbittorrent_mullvad_autobind.log"

# Create log file if it doesn't exist
touch "$LOG_FILE"

log() {
  echo "$(date): $1" >> "$LOG_FILE"
}

log "Script started"

# Check if Mullvad is running
if ! pgrep -q "Mullvad VPN"; then
  log "Mullvad VPN is not running. Exiting."
  exit 1
fi

# Wait for VPN to establish connection
sleep 3

# Find the Mullvad interface
# This typically looks for utun or tun interfaces that are up
MULLVAD_INTERFACE=$(ifconfig | grep -B 1 "inet " | grep -v "inet6\|127.0.0.1" | grep -E "utun|tun" | head -n 1 | cut -d: -f1)

if [ -z "$MULLVAD_INTERFACE" ]; then
  log "Could not find Mullvad interface. Exiting."
  exit 1
fi

log "Found Mullvad interface: $MULLVAD_INTERFACE"

# Check if qBittorrent config exists
if [ ! -f "$QBITTORRENT_CONFIG" ]; then
  log "qBittorrent config not found at $QBITTORRENT_CONFIG. Exiting."
  exit 1
fi

# Backup the config file
cp "$QBITTORRENT_CONFIG" "${QBITTORRENT_CONFIG}.bak"
log "Backed up qBittorrent config to ${QBITTORRENT_CONFIG}.bak"

# Update the network interface in qBittorrent config
# Update Session\Interface and Session\InterfaceName
if grep -q "^Session\\\\Interface=" "$QBITTORRENT_CONFIG"; then
  # Replace existing Session\Interface setting
  sed -i '' "s|^Session\\\\Interface=.*|Session\\\\Interface=$MULLVAD_INTERFACE|" "$QBITTORRENT_CONFIG"
else
  # Add Session\Interface setting
  echo "Session\\Interface=$MULLVAD_INTERFACE" >> "$QBITTORRENT_CONFIG"
fi

if grep -q "^Session\\\\InterfaceName=" "$QBITTORRENT_CONFIG"; then
  # Replace existing Session\InterfaceName setting
  sed -i '' "s|^Session\\\\InterfaceName=.*|Session\\\\InterfaceName=$MULLVAD_INTERFACE|" "$QBITTORRENT_CONFIG"
else
  # Add Session\InterfaceName setting
  echo "Session\\InterfaceName=$MULLVAD_INTERFACE" >> "$QBITTORRENT_CONFIG"
fi

log "Updated qBittorrent config to use interface $MULLVAD_INTERFACE (Session\\Interface and Session\\InterfaceName)"

# Check if qBittorrent is running and restart it
if pgrep -q "qbittorrent"; then
  log "qBittorrent is running. Restarting it..."
  pkill qbittorrent
  sleep 2
  open -a qBittorrent
  log "qBittorrent restarted"
else
  log "qBittorrent is not running. No need to restart."
fi

log "Script completed successfully"
exit 0
SCRIPT_EOF

# Make the script executable
chmod +x "$HOME/Scripts/qbittorrent_mullvad_autobind.sh"
echo -e "${GREEN}✓ Created autobind script${NC}"

# Create the Launch Agent plist
echo "Creating Launch Agent..."
cat > "$HOME/Library/LaunchAgents/com.user.mullvad.qbittorrent.plist" << 'PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.mullvad.qbittorrent</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/sh</string>
        <string>-c</string>
        <string>bash ~/Scripts/qbittorrent_mullvad_autobind.sh</string>
    </array>
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

echo -e "${GREEN}✓ Created Launch Agent plist${NC}"

# Check if qBittorrent config exists
if [ ! -f "$HOME/.config/qBittorrent/qBittorrent.ini" ]; then
    echo ""
    echo -e "${YELLOW}Warning: qBittorrent config file not found at ~/.config/qBittorrent/qBittorrent.ini${NC}"
    echo -e "${YELLOW}Please open qBittorrent and go to Preferences at least once to create the config file.${NC}"
    echo ""
fi

# Unload existing launch agent if it exists
if launchctl list | grep -q "com.user.mullvad.qbittorrent"; then
    echo "Unloading existing Launch Agent..."
    launchctl unload "$HOME/Library/LaunchAgents/com.user.mullvad.qbittorrent.plist" 2>/dev/null || true
fi

# Load the launch agent
echo "Loading Launch Agent..."
launchctl load "$HOME/Library/LaunchAgents/com.user.mullvad.qbittorrent.plist"

# Verify it's loaded
if launchctl list | grep -q "com.user.mullvad.qbittorrent"; then
    echo -e "${GREEN}✓ Launch Agent loaded successfully${NC}"
else
    echo -e "${RED}✗ Failed to load Launch Agent${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo "The autobind script will now run automatically whenever your network changes."
echo ""
echo "Useful commands:"
echo "  • Test manually: ~/Scripts/qbittorrent_mullvad_autobind.sh"
echo "  • View logs: cat ~/Library/Logs/qbittorrent_mullvad_autobind.log"
echo "  • Unload agent: launchctl unload ~/Library/LaunchAgents/com.user.mullvad.qbittorrent.plist"
echo "  • Reload agent: launchctl unload ~/Library/LaunchAgents/com.user.mullvad.qbittorrent.plist && launchctl load ~/Library/LaunchAgents/com.user.mullvad.qbittorrent.plist"
echo ""

