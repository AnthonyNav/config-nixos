{ pkgs, ... }:

{
  home.packages = with pkgs; [
    bruno
    postman
    httpie
    grpcurl
    cloudflared
    harlequin
    usql
  ];
}
