{ pkgs, ... }:
let
  api = import ../../../packages/api-tools.nix { inherit pkgs; };
in

{
  home.packages = with pkgs; [
    api.bruno
    api.postman
    api.posting
    hurl
    httpie
    grpcurl
    cloudflared
    harlequin
    usql
  ];
}
