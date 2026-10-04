{ lib, ... }:

{
  # The observed journal used 3.9 GiB. Bound future retention, not app memory.
  services.journald.settings.Journal = {
    SystemMaxUse = "1G";
    RuntimeMaxUse = "128M";
    MaxRetentionSec = "14day";
  };
  # Bound both levels of build parallelism. These are defaults, not CPU or
  # memory quotas: a package can ignore NIX_BUILD_CORES.
  nix.settings = {
    max-jobs = lib.mkDefault 2;
    cores = lib.mkDefault 2;
  };
  nix.daemonCPUSchedPolicy = "batch";
  systemd.services.nix-daemon.serviceConfig = {
    CPUWeight = lib.mkDefault 50;
    IOWeight = lib.mkDefault 50;
  };

  # Keep the existing retention window; reduce competition from weekly GC.
  systemd.services.nix-gc.serviceConfig = {
    Nice = 10;
    IOSchedulingClass = "best-effort";
    IOSchedulingPriority = 7;
    CPUWeight = 25;
    IOWeight = 25;
  };
}
