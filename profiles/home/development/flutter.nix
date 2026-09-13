{ pkgs, ... }:

{
  home.packages = with pkgs; [
    android-studio
    flutter
    fvm
    android-tools
    clang
    cmake
    ninja
    pkg-config
  ];
}
