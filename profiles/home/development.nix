{ pkgs, ... }:

let
  claude-code = pkgs.claude-code.overrideAttrs (_: rec {
    version = "2.1.237";
    src = pkgs.fetchurl {
      url = "https://downloads.claude.ai/claude-code-releases/${version}/linux-x64/claude";
      sha256 = "73975167f0108693cf6fd6614994781657ebb8456ebef5d247458734abfb3916";
    };
  });
in

{
  imports = [
    ../../modules/home/zsh.nix
    ../../modules/home/nix-config.nix
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
    awscli2
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
