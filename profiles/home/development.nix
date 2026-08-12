{ pkgs, ... }:

{
  imports = [
    ../../modules/home/zsh.nix
    ../../modules/home/nixos-update.nix
    ../../modules/home/kiro-gateway.nix
    ../../modules/home/opencode.nix
  ];

  home.packages = with pkgs; [
    vscode
    vim
    nano
    neovim
    android-studio
    flutter
    nodejs_22
    go
    kotlin
    fvm
    android-tools
    docker-compose
    bruno
    postman
    insomnia
    gotestsum
    mockgen
    kiro
    kiro-cli
    antigravity-ide
    claude-code
    rtk
    python3
    python3Packages.pip
    micromamba
    uv
    gcc
    gnumake
    cmake
    gdb
    dotnet-sdk_8
    grpcurl
    httpie
    cloudflared
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
    # El binario queda disponible, pero no instala hooks SQLite en cada shell.
    # Ctrl-R y las flechas ya pertenecen a fzf/history-substring-search.
    enableZshIntegration = false;
  };
}
