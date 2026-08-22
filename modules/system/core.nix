{
  lib,
  pkgs,
  username,
  ...
}:

{
  imports = [
    ./pritunl.nix
    ./tailscale-fleet.nix
    ./syncthing-fleet.nix
    ./remote-workspace.nix
  ];

  networking.networkmanager.enable = true;

  time.timeZone = "America/Mexico_City";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "es_MX.UTF-8";
    LC_MONETARY = "es_MX.UTF-8";
    LC_MEASUREMENT = "es_MX.UTF-8";
    LC_PAPER = "es_MX.UTF-8";
  };
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "es_MX.UTF-8/UTF-8"
    "C.UTF-8/UTF-8"
  ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    substituters = lib.mkAfter [
      "https://nix-community.cachix.org"
      "https://hyprland.cachix.org"
    ];
    trusted-public-keys = lib.mkAfter [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nixpkgs.config.allowUnfree = true;

  programs.zsh = {
    enable = true;
    enableGlobalCompInit = false;
    promptInit = "";
  };
  programs.ssh.startAgent = true;

  users.users.${username} = {
    isNormalUser = true;
    description = username;
    shell = pkgs.zsh;
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
      "docker"
      "kvm"
    ];
    packages = with pkgs; [
      fastfetch
      neovim
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMSZBAoRb/gxevgsIFbtcg/hPx+gvv0tfj25KtubL0xd anthony@config-nixos"
    ];
  };

  hardware.bluetooth.enable = true;
  services.power-profiles-daemon.enable = true;
  virtualisation.docker.enable = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };
  services.fstrim.enable = true;
  services.fwupd.enable = true;

  environment.systemPackages = with pkgs; [
    google-chrome
    nh
  ];

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
  ];

  environment.variables = {
    FLAKE = "/home/${username}/nixos-config";
  };

  environment.sessionVariables = {
    FLAKE = "/home/${username}/nixos-config";
    NIXOS_OZONE_WL = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
  };
}
