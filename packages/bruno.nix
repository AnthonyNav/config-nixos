{
  pkgs,
  lib ? pkgs.lib,
}:
pkgs.stdenvNoCC.mkDerivation rec {
  pname = "bruno";
  version = "4.2.1";
  src = pkgs.fetchurl {
    url = "https://github.com/usebruno/bruno/releases/download/v${version}/bruno_${version}_amd64_linux.deb";
    hash = "sha256-fDbw1/FYmbtIqymNNi2idB7cOSxwL68T3ZbuEq/Ueog=";
  };
  nativeBuildInputs = [
    pkgs.dpkg
    pkgs.autoPatchelfHook
    pkgs.makeWrapper
  ];
  buildInputs = with pkgs; [
    stdenv.cc.cc.lib
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libdrm
    libgbm
    libglvnd
    libsecret
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    nspr
    nss
    pango
  ];
  runtimeDependencies = [
    (lib.getLib pkgs.systemd)
    (lib.getLib pkgs.libglvnd)
  ];
  unpackPhase = ''${pkgs.dpkg}/bin/dpkg-deb -x "$src" .'';
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/share"
    cp -r opt/Bruno "$out/app"
    cp -r usr/share/applications usr/share/icons "$out/share/"
    makeWrapper "$out/app/bruno" "$out/bin/bruno"
    substituteInPlace "$out/share/applications/bruno.desktop" \
      --replace-fail 'Exec=/opt/Bruno/bruno' "Exec=$out/bin/bruno"
    runHook postInstall
  '';
  meta = {
    description = "Git-friendly API client, pinned to the security release";
    homepage = "https://www.usebruno.com";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "bruno";
    platforms = [ "x86_64-linux" ];
  };
}
