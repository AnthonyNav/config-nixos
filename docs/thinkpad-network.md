# ThinkPad Network Diagnostics

The ThinkPad has development tools and network diagnostics. NetworkManager
power saving is disabled for this host because measurements showed high LAN
latency and retry counts even with excellent signal. Slow performance in a busy
environment can still be caused by RF congestion, AP band steering, the adapter
driver or firmware, VPN routing, MTU, DNS, or the Internet path.

The shared Caelestia package is patched in `modules/home/caelestia-scheme.nix`.
Nexus and the bar request credentials before changing networks, activate saved
profiles by UUID, perform a single connection attempt, and never pin a visible
network to the BSSID selected during the scan. A fixed
`802-11-wireless.bssid` prevents NetworkManager from roaming between access
points with the same SSID. Existing mutable profiles must be repaired once with
`nmcli`; passwords and connection profiles do not belong in this repository.

## Baseline

Run these commands on the ThinkPad and save the output with the date, location,
SSID, BSSID, VPN state, and AC or battery state:

```sh
lspci -nnk
rfkill list
nmcli connection show --active
ip route
ip rule
iw reg get
cat /proc/cmdline
```

Replace `wlp...` with the Wi-Fi interface:

```sh
nmcli -f GENERAL,WIFI-PROPERTIES,IP4,DHCP4 device show wlp...
iw dev wlp... link
iw dev wlp... station dump
iw dev wlp... survey dump
ethtool -i wlp...
journalctl -b -k | grep -Ei 'iwlwifi|wifi|wlan|cfg80211'
journalctl -b -u NetworkManager
```

Use `wavemon` for a live view. A scan can briefly disturb traffic:

```sh
nmcli device wifi list --rescan yes
```

## Measure The LAN First

Run an `iperf3` server on an Ethernet-connected machine in the same LAN:

```sh
iperf3 -s
```

Run this matrix from ThinkPad five times per command, while pinging the default
gateway in another terminal:

```sh
iperf3 -c <lan-server> -t 60
iperf3 -c <lan-server> -t 60 -R
iperf3 -c <lan-server> -t 60 -P 4
ping <default-gateway>
```

Repeat with Pritunl disconnected and connected. Good LAN results with poor
Internet results indicate a VPN, MTU, DNS, ISP, or remote endpoint issue, not
necessarily Wi-Fi.

## Controlled Experiments

Do not apply the entire historical ThinkPad branch. Make one host-scoped change
in `hosts/thinkpad/default.nix`, test it, then retain or remove it based on the
same benchmark matrix.

### NetworkManager Power Save

The retained host-scoped setting is:

```nix
networking.networkmanager.wifi.powersave = false;
```

This can improve sustained throughput or latency but consumes more battery.
Keep it only if repeated LAN results improve without worse packet loss or p95
gateway latency.

### Saved Profile Roaming

Check that a multi-AP network is not pinned and does not have competing
profiles:

```sh
nmcli -f NAME,UUID,TYPE,AUTOCONNECT connection show
nmcli -f connection.id,802-11-wireless.ssid,802-11-wireless.bssid,802-11-wireless.powersave connection show <profile>
```

Clear an unwanted pin without changing the saved password, then reconnect:

```sh
nmcli connection modify <profile> 802-11-wireless.bssid ""
nmcli connection down <profile>
nmcli connection up <profile>
```

Caelestia must not disconnect the current network merely by opening or
cancelling its password page. A submitted connection necessarily asks the
single Wi-Fi radio to move to the target AP, so test invalid and valid passwords
only when a brief interruption is acceptable. After connecting through Nexus,
verify that exactly one profile exists and `802-11-wireless.bssid` remains
empty.

### Regulatory Domain

Only test this if the computer is operated in Mexico and `iw reg get` shows a
world domain or unavailable legal 5/6 GHz channels:

```nix
boot.kernelParams = [ "cfg80211.ieee80211_regdom=MX" ];
```

It requires a reboot. Verify both `cat /proc/cmdline` and `iw reg get` after
booting the test generation. It does not force a better band or solve AP
congestion by itself.

## Rollback

Use `nixos-rebuild test` for non-kernel experiments. For a kernel parameter,
build a bootable generation and select the previous generation from systemd-boot
if the result worsens. ThinkPad retains five boot generations.
