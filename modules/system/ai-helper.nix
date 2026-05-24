{ pkgs, ... }:

{
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      alsa-lib
      at-spi2-core
      cairo
      cups
      expat
      fontconfig
      freetype
      glib
      gtk3
      icu
      libdrm
      libgbm
      libexif
      libnotify
      libsecret
      libuuid
      libx11
      libxcursor
      libxkbcommon
      libxrandr
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

  environment.systemPackages = with pkgs; [
    appimage-run
    direnv
    file
    gh
    git
    jq
    nix-direnv
    patchelf
    ripgrep
  ];
}
