{ pkgs, ... }:
{
  # Xcode, its license and simulators remain platform-owned. Flutter versions
  # belong to projects; FVM selects their SDK without a second global Flutter.
  home.packages = with pkgs; [
    fvm
    cocoapods
  ];
}
