## Mullvad Autobind for qBittorrent

This autobinds qBittorrent to use Mullvad's network interface on macOS.

To install, clone this repo and from the terminal, run:

`./install.sh`

Then, simply disconnect and reconnect to Mullvad to trigger the update for the first time, if you want. Post installation, the LaunchAgent will automatically pick up any changes to Mullvad's interface and restart qBittorrent as needed.

Note that this assumes that you have both the Mullvad macOS desktop client and qBittorrent installed.

