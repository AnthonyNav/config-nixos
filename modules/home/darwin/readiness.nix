{
  config,
  hostFeatures,
  lib,
  pkgs,
  ...
}:
{
  # Darwin-only: validate the native setup and cross-platform tool availability
  # without opening apps, changing state, or inspecting account credentials.
  home.packages = [
    (import ../../../packages/macos-readiness.nix {
      inherit pkgs lib;
      hostName = hostFeatures.hostName;
      username = config.home.username;
      homeDirectory = config.home.homeDirectory;
    })
  ];
}
