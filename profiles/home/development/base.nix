{ pkgs, ... }:

{
  imports = [
    ../../../modules/home/zsh.nix
    ../../../modules/home/nix-config.nix
  ];

  home.packages = with pkgs; [
    vscode
    nano
    neovim
    docker-compose
    zoxide
    atuin
    lazygit
    delta
    yazi
    zsh-fzf-tab
    zsh-history-substring-search
    zip
    unzip
    p7zip
    gzip
    bzip2
    xz
    zstd
    lz4
    rar
    wget
    curl
  ];

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.atuin = {
    enable = true;
    enableZshIntegration = false;
  };
}
