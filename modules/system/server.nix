{ lib, ... }:
{
  # Server operation must survive closing the lid and unattended idle periods.
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };
  systemd.sleep.settings.Sleep = {
    AllowSuspend = false;
    AllowHibernation = false;
    AllowHybridSleep = false;
    AllowSuspendThenHibernate = false;
  };
  # A conservative baseline, overridden only after measuring the real server.
  nix.settings = {
    max-jobs = lib.mkOverride 900 1;
    cores = lib.mkOverride 900 1;
  };
}
