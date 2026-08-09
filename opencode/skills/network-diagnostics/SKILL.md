---
name: network-diagnostics
description: Use when diagnosing slow, unstable, high-latency, or congested network connections on NixOS, especially the ThinkPad Wi-Fi issue.
---

# Network Diagnostics

1. Measure local LAN performance with `iperf3` before using an Internet speed
   test. Separate Wi-Fi from VPN, ISP, DNS, and remote-server effects.
2. Record adapter driver, firmware, regulatory domain, BSSID, frequency, RSSI,
   retry counters, survey data, gateway latency, and VPN state.
3. Change one variable at a time. Do not force Wi-Fi standards, driver module
   parameters, or a regulatory domain without evidence.
4. Keep persistent experiments scoped to `hosts/thinkpad/default.nix` and use a
   reversible NixOS generation.

Use `docs/thinkpad-network.md` as the measurement protocol.
