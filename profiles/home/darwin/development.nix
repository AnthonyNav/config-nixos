{ pkgs, ... }:
{
  imports = [ ../development/spec-kit.nix ];
  # Language versions belong to project devShells. Native GUI applications
  # and the VM runtime belong to the Darwin system's Homebrew policy.
  home.packages = with pkgs; [
    lazygit
    delta
    docker-client
    docker-compose
    uv
    hurl
    httpie
    grpcurl
    cloudflared
    harlequin
    usql
  ];
}
