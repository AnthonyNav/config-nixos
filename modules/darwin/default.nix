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
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [ "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
  };
  system.stateVersion = 6;
  # Homebrew itself is installed explicitly during onboarding. Activation may
  # manage only these native apps; it must not uninstall unrelated user apps.
  homebrew = {
    enable = lib.mkDefault true;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "none";
    };
    taps = [ "stablyai/orca" ];
    casks = [
      "orca"
      "tailscale-app"
    ]
    ++ lib.optional development "visual-studio-code"
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
      message = "Use the standalone macOS Tailscale application, without a second Nix daemon.";
    }
  ];
}
