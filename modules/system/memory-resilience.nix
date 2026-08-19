{ ... }:

{
  # Keep a compressed in-memory swap tier for short RAM spikes. The zram
  # device is allocated on demand; memoryPercent is its logical capacity,
  # not an upfront reservation of half the physical RAM.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # NixOS enables systemd-oomd by default, but it does not monitor user
  # slices unless requested. Monitor interactive/user workloads so sustained
  # memory pressure can shed the offending workload before the workstation
  # becomes unresponsive. Keep system/root slices out of the policy so core
  # services remain outside this proactive kill domain.
  systemd.oomd = {
    enable = true;
    enableUserSlices = true;
    enableSystemSlice = false;
    enableRootSlice = false;
  };
}
