{ kiroPackages, pkgs, ... }:

{
  # Desktop additions to the same core modules used by the laptop roles.
  imports = [
    ./development/base.nix
    ./development/web-backend.nix
    ./development/ai.nix
    ./development/spec-kit.nix
    ../../modules/home/remote-workspace.nix
  ];

  home.packages = with pkgs; [
    vim
    android-studio
    flutter
    kotlin
    fvm
    android-tools
    bruno
    postman
    insomnia
    kiroPackages.ide
    antigravity-ide
    python3Packages.pip
    micromamba
    gnumake
    cmake
    gdb
    dotnet-sdk_8
    grpcurl
    httpie
    cloudflared
  ];
}
