{ lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    nodejs_22
    go
    (lib.hiPrio gcc)
    gotestsum
    mockgen
    python3
    uv
  ];
}
