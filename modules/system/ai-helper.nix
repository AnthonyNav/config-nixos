{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.fleet.agentRuntime.antigravityCli = lib.mkEnableOption "the nsjail companion for a separately declared managed Antigravity CLI";

  config = {
    programs.nix-ld = {
      enable = true;
      # Runtime de herramientas administradas; las actualizaciones pasan por Nix.
      # como Codex, Antigravity, Claude Code, OpenCode y CLIs/AppImages afines.
      libraries = with pkgs; [
        alsa-lib
        atk
        at-spi2-core
        cairo
        cups
        expat
        fontconfig
        freetype
        glib
        gtk3
        gnumake
        icu
        libbsd
        libdrm
        libgbm
        libglvnd
        libexif
        libjpeg
        libnotify
        libpng
        libpulseaudio
        libsecret
        libuuid
        libxcb
        libxcb-cursor
        libice
        libsm
        libx11
        libxcomposite
        libxcursor
        libxdamage
        libxext
        libxfixes
        libxkbcommon
        libxkbfile
        libxrandr
        libxrender
        libxi
        libxtst
        mesa
        nspr
        nss
        stdenv.cc.cc
        dbus
        openssl
        pango
        zlib
      ];
    };

    environment.systemPackages =
      with pkgs;
      [
        appimage-run
        bubblewrap
        direnv
        file
        gh
        git
        jq
        nix-direnv
        patchelf
        ripgrep
        socat
      ]
      ++ lib.optional config.fleet.agentRuntime.antigravityCli pkgs.nsjail;
  };
}
