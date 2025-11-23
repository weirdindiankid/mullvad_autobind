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

# Find the Mullvad interface using multiple detection methods
get_mullvad_interface() {
  local interface=""

  # Method 1: Use Mullvad CLI if available (most reliable)
  if command -v mullvad &> /dev/null; then
    log "Attempting to get interface from Mullvad CLI..."
    local mullvad_status=$(mullvad status 2>/dev/null)

    # Check if connected and extract interface
    if echo "$mullvad_status" | grep -q "Connected"; then
      # Try to get interface from status output
      interface=$(echo "$mullvad_status" | grep -oE "(utun|tun|wg)[0-9]+" | head -n 1)

      if [ -n "$interface" ]; then
        log "Found interface from Mullvad CLI: $interface"
        echo "$interface"
        return 0
      fi
    else
      log "Mullvad CLI reports not connected: $mullvad_status"
    fi
  fi

  # Method 2: Check routing table for Mullvad's characteristic routes
  log "Checking routing table for Mullvad interface..."
  # Mullvad typically routes all traffic through its interface
  interface=$(netstat -rn | grep -E "^0\.0\.0\.0|^default" | grep -oE "(utun|tun|wg)[0-9]+" | head -n 1)

  if [ -n "$interface" ]; then
    # Validate this interface has an active connection
    if ifconfig "$interface" 2>/dev/null | grep -q "inet "; then
      log "Found interface from routing table: $interface"
      echo "$interface"
      return 0
    fi
  fi

  # Method 3: Look for utun/wg interfaces with private IP ranges (Mullvad uses 10.x.x.x)
  log "Searching for active VPN interfaces with private IPs..."
  for iface in $(ifconfig | grep -E "^(utun|tun|wg)[0-9]+" | cut -d: -f1); do
    local ip=$(ifconfig "$iface" 2>/dev/null | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | head -n 1)

    if [ -n "$ip" ]; then
      # Mullvad typically uses 10.x.x.x range
      if echo "$ip" | grep -qE "^10\."; then
        log "Found interface $iface with Mullvad-like IP: $ip"
        echo "$iface"
        return 0
      fi
    fi
  done

  # Method 4: Fallback to any active utun/wg interface (least reliable)
  log "Falling back to first available utun/wg interface..."
  interface=$(ifconfig | grep -B 1 "inet " | grep -v "inet6\|127.0.0.1" | grep -oE "^(utun|wg|tun)[0-9]+" | head -n 1)

  if [ -n "$interface" ]; then
    log "Found fallback interface: $interface (WARNING: not validated as Mullvad)"
    echo "$interface"
    return 0
  fi

  return 1
}

MULLVAD_INTERFACE=$(get_mullvad_interface)

if [ -z "$MULLVAD_INTERFACE" ]; then
  log "ERROR: Could not find Mullvad interface after trying all detection methods."
  log "Please ensure Mullvad VPN is connected and check the log for details."
  exit 1
fi

log "Successfully detected Mullvad interface: $MULLVAD_INTERFACE"

# Validate the interface is actually up and has an IP
if ! ifconfig "$MULLVAD_INTERFACE" 2>/dev/null | grep -q "inet "; then
  log "ERROR: Interface $MULLVAD_INTERFACE exists but has no IP address. VPN may not be fully connected."
  exit 1
fi

INTERFACE_IP=$(ifconfig "$MULLVAD_INTERFACE" | grep "inet " | awk '{print $2}' | head -n 1)
log "Interface $MULLVAD_INTERFACE is active with IP: $INTERFACE_IP"

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
