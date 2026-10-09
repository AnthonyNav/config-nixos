_: {
  # This workstation is explicitly authorized to use the native work VPN.
  # Its package owns privileged launchd services; other Macs opt in separately.
  homebrew.casks = [ "pritunl" ];

  # Apple M5, 16 GiB RAM. Leave room for the editor, simulators and local work.
  nix.settings = {
    max-jobs = 2;
    cores = 2;
  };
}
