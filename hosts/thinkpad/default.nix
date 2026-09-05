{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/system
  ];

  networking.hostName = "thinkpad";

  # This 16 GiB workstation needs memory headroom for the evaluator and IDEs.
  nix.settings.max-jobs = 1;
  systemd.services.nix-daemon.serviceConfig = {
    CPUWeight = 25;
    IOWeight = 25;
  };

  # The socket still starts Docker on first use. Containers with restart
  # policies resume when the daemon starts, rather than automatically at boot.
  virtualisation.docker.enableOnBoot = false;

  # Zram remains the first tier (priority 5). Disk swap is an emergency buffer,
  # encrypted with an ephemeral key so swapped application data is not stored
  # in plaintext on the unencrypted ext4 root filesystem.
  swapDevices = [
    {
      device = "/var/lib/nixos-memory-swapfile";
      size = 8192;
      priority = 0;
      randomEncryption.enable = true;
    }
  ];
  systemd.sleep.settings.Sleep = {
    AllowHibernation = false;
    AllowHybridSleep = false;
    AllowSuspendThenHibernate = false;
  };

  # Prioriza latencia y throughput estables en redes congestionadas. Se limita
  # a este host porque el coste de bateria y el adaptador varian por equipo.
  networking.networkmanager.wifi.powersave = false;

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Diagnóstico de red local. Los ajustes de ahorro de energía y regulatory
  # domain se prueban después con métricas, no se presuponen como solución.
  environment.systemPackages = with pkgs; [
    pciutils
    iw
    ethtool
    iperf3
    wavemon
  ];

  system.stateVersion = "24.11";
}
