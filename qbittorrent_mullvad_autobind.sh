#!/bin/bash

# Script to autobind qBittorrent to Mullvad VPN interface on macOS
# Save to ~/Scripts/qbittorrent_mullvad_autobind.sh and make executable with:
# chmod +x ~/Scripts/qbittorrent_mullvad_autobind.sh

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

# Check if qBittorrent is running
QBITTORRENT_WAS_RUNNING=false
if pgrep -q "qbittorrent"; then
  QBITTORRENT_WAS_RUNNING=true
  log "qBittorrent is running. Force killing to prevent config overwrite..."

  # Force kill immediately to prevent qBittorrent from writing its in-memory config to disk
  pkill -9 qbittorrent

  # Wait to ensure process is fully terminated and file handles are released
  sleep 3

  # Double check it's really dead
  if pgrep -q "qbittorrent"; then
    log "Warning: qBittorrent still running after force kill, trying again..."
    pkill -9 qbittorrent
    sleep 3
  fi

  log "qBittorrent killed successfully"
fi

# Update the network interface in qBittorrent config using awk for safer file manipulation
TEMP_FILE="${QBITTORRENT_CONFIG}.tmp"

awk -v interface="$MULLVAD_INTERFACE" '
BEGIN {
  found_interface = 0
  found_interface_name = 0
  in_bittorrent_section = 0
}
/^\[BitTorrent\]/ {
  in_bittorrent_section = 1
  print
  next
}
/^\[.*\]/ {
  # If we are leaving BitTorrent section and havent added the settings, add them now
  if (in_bittorrent_section && (!found_interface || !found_interface_name)) {
    if (!found_interface) {
      print "Session\\Interface=" interface
    }
    if (!found_interface_name) {
      print "Session\\InterfaceName=" interface
    }
  }
  in_bittorrent_section = 0
  found_interface = 0
  found_interface_name = 0
  print
  next
}
/^Session\\Interface=/ {
  if (in_bittorrent_section) {
    print "Session\\Interface=" interface
    found_interface = 1
    next
  }
}
/^Session\\InterfaceName=/ {
  if (in_bittorrent_section) {
    print "Session\\InterfaceName=" interface
    found_interface_name = 1
    next
  }
}
# Remove any corrupted Interface lines in Preferences section
/^Interface=/ {
  next
}
{
  print
}
END {
  # If we never found BitTorrent section, add it with the settings
  if (!in_bittorrent_section && (!found_interface || !found_interface_name)) {
    print ""
    print "[BitTorrent]"
    print "Session\\Interface=" interface
    print "Session\\InterfaceName=" interface
  }
}
' "$QBITTORRENT_CONFIG" > "$TEMP_FILE"

# Replace the original file with the updated one
mv "$TEMP_FILE" "$QBITTORRENT_CONFIG"

log "Updated qBittorrent config to use interface $MULLVAD_INTERFACE (Session\\Interface and Session\\InterfaceName)"

# Restart qBittorrent if it was running
if [ "$QBITTORRENT_WAS_RUNNING" = true ]; then
  log "Restarting qBittorrent..."
  sleep 2
  open -a qBittorrent
  log "qBittorrent restarted with new interface binding"
else
  log "qBittorrent was not running. Configuration updated for next launch."
fi

log "Script completed successfully"
exit 0
