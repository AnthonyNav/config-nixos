{
  config,
  lib,
  pkgs,
  username,
  homeDirectory,
  hostFeatures,
  ...
}:
let
  development = builtins.elem "development" hostFeatures.homeProfiles;
  mobile = builtins.elem "mobile" hostFeatures.homeProfiles;
in
{
  nixpkgs.config.allowUnfree = true;
  networking.hostName = hostFeatures.hostName;
  system.primaryUser = username;
  users.users.${username}.home = homeDirectory;
  programs.zsh.enable = true;
  environment.shells = [ pkgs.zsh ];
  environment.systemPath = lib.optionals config.homebrew.enable [
    "${config.homebrew.prefix}/bin"
    "${config.homebrew.prefix}/sbin"
  ];
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [ "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
  };
  system.stateVersion = 6;

  # Functional keyboard defaults only. Visual appearance remains user-owned.
  system.defaults.NSGlobalDomain = {
    AppleKeyboardUIMode = 2;
    ApplePressAndHoldEnabled = false;
    InitialKeyRepeat = 15;
    KeyRepeat = 2;
  };
  # Homebrew itself is installed explicitly during onboarding. Activation may
  # manage only these native apps; it must not uninstall unrelated user apps.
  homebrew = {
    enable = lib.mkDefault true;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "none";
    };
    taps = [
      "stablyai/orca"
      "nikitabobko/tap"
    ];
    # Keep the existing App Store variant; the standalone cask cannot replace
    # it safely during a remote activation.
    masApps.Tailscale = 1475387142;
    # The unqualified `orca` resolves to Plotly's unrelated, disabled cask.
    casks = [
      "stablyai/orca/orca"
      "kitty"
      "hammerspoon"
      "karabiner-elements"
      "aerospace"
    ]
    ++ lib.optional development "visual-studio-code"
    ++ lib.optional development "dbgate"
    ++ lib.optional mobile "android-studio";
    brews = lib.optionals development [ "colima" ];
  };
  assertions = [
    {
      assertion = hostFeatures.platform == "darwin" && pkgs.stdenv.hostPlatform.isDarwin;
      message = "Darwin system modules require a Darwin inventory host.";
    }
    {
      assertion = !config.services.tailscale.enable;
      message = "Use the native macOS Tailscale application, without a second Nix daemon.";
    }
  ];
}
