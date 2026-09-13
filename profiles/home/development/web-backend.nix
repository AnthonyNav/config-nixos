{ pkgs, ... }:

{
  home.packages = with pkgs; [
    nodejs_22
    go
    gotestsum
    mockgen
    python3
    uv
  ];
}
