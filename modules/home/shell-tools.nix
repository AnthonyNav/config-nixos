{ pkgs, ... }:
{
  imports = [
    ./zsh.nix
    ./nix-config.nix
  ];
  home.packages = with pkgs; [
    nano
    bottom
    fastfetch
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
    # Shared essentials for interactive terminals and coding agents.
    ripgrep
    jq
    fd
  ];
  programs = {
    btop = {
      enable = true;
      settings = {
        theme_background = false;
        truecolor = true;
      };
    };
    bat = {
      enable = true;
      config.style = "numbers,changes,header";
    };
    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };
    atuin = {
      enable = true;
      enableZshIntegration = false;
    };
  };
}
