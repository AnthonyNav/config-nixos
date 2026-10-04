{ pkgs, ... }:
{
  home.packages = with pkgs; [
    vscode
    docker-compose
    lazygit
    delta
  ];
}
