{
  lib,
  stdenvNoCC,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  asar,
  python3,
  stdenv,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libglvnd,
  libsecret,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  nspr,
  nss,
  pango,
  systemd,
  bash,
  writeShellScript,
  makeWrapper,
}:
let
  version = "1.4.220";
  unwrapped = stdenvNoCC.mkDerivation {
    pname = "orca-ide-unwrapped";
    inherit version;
    src = fetchurl {
      url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-ide_${version}_amd64.deb";
      hash = "sha256-XDPn4dPKfyM6moLateVkAmUfkuo8xJPx1otMBilfsKw=";
    };
    nativeBuildInputs = [
      dpkg
      autoPatchelfHook
      asar
      python3
    ];
    buildInputs = [
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
      (lib.getLib systemd)
      (lib.getLib libglvnd)
    ];
    unpackPhase = ''dpkg-deb -x "$src" .'';
    dontConfigure = true;
    dontBuild = true;
    # Native execution preserves root ownership of Home Manager store links.
    # An FHS user namespace makes those links fail OpenSSH ownership checks.
    postPatch = ''
      asar extract opt/Orca/resources/app.asar asar-source
      python ${./orca-native-shell.py} asar-source/out/main/index.js ${lib.getExe bash}
      # The foreground server bypasses the node-mode CLI supervisor. Review
      # this contract whenever the pinned upstream payload changes.
      for flag in --serve --serve-json --serve-port --serve-pairing-address; do
        grep -q -- "$flag" asar-source/out/main/index.js
      done
      # Unpack all members so autoPatchelf also reaches native modules. Keep
      # Electron's app.asar entry point and packaged-app semantics intact.
      rm -r opt/Orca/resources/app.asar opt/Orca/resources/app.asar.unpacked
      asar pack asar-source opt/Orca/resources/app.asar --unpack '**'
    '';
    installPhase = ''
      runHook preInstall
      test "$(cat opt/Orca/resources/package-type)" = deb
      mkdir -p "$out"
      cp -r opt/Orca "$out/app"
      cp -r usr/share "$out/share"
      runHook postInstall
    '';
    # These are deployment payloads for remote glibc/musl/ARM hosts. Patching
    # them to this workstation's /nix/store would break remote SSH worktrees.
    # Restore them AFTER autoPatchelf and the generic local fixups finish.
    preFixup = ''
      if [ -d "$out/app/resources/orcad-template" ]; then
        remoteTemplate="$(mktemp -d)"
        mv "$out/app/resources/orcad-template" "$remoteTemplate/"
        restoreRemoteTemplate() {
          mv "$remoteTemplate/orcad-template" "$out/app/resources/"
        }
        postFixupHooks+=(restoreRemoteTemplate)
      fi
    '';
  };
  launcher = writeShellScript "orca-ide-launch" ''
    set -eu
    export ORCA_TELEMETRY_DISABLED=1
    # Preserve upstream's externally-managed-install guard. A Debian package
    # manager on this host would allow Orca to bypass Nix-owned updates.
    for manager in /usr/bin/apt /bin/apt /usr/sbin/apt /sbin/apt \
      /usr/bin/dpkg /bin/dpkg /usr/sbin/dpkg /sbin/dpkg; do
      if [ -x "$manager" ]; then
        echo "Orca's Nix installation must not use apt or dpkg." >&2
        exit 1
      fi
    done
    mode="$1"
    shift
    case "$mode" in
      cli) exec ${lib.getExe bash} ${unwrapped}/app/resources/bin/orca-ide "$@" ;;
      gui) exec ${unwrapped}/app/orca-ide "$@" ;;
      server)
        unset ELECTRON_RUN_AS_NODE
        # Headless owns an Xvfb display even when the user manager inherited
        # Wayland preferences from an earlier graphical login.
        exec ${unwrapped}/app/orca-ide --serve --ozone-platform=x11 "$@"
        ;;
      *) exit 64 ;;
    esac
  '';
in
stdenvNoCC.mkDerivation {
  pname = "orca-ide";
  inherit version;
  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/share/applications"
    makeWrapper ${launcher} "$out/bin/orca-ide" --add-flags cli
    makeWrapper ${launcher} "$out/bin/orca-ide-gui" --add-flags gui
    makeWrapper ${launcher} "$out/bin/orca-ide-server" --add-flags server
    cp ${unwrapped}/share/applications/orca-ide.desktop "$out/share/applications/"
    substituteInPlace "$out/share/applications/orca-ide.desktop" \
      --replace-fail 'Exec=/opt/Orca/orca-ide' "Exec=$out/bin/orca-ide-gui"
    ln -s ${unwrapped}/share/icons "$out/share/icons"
    runHook postInstall
  '';
  passthru = { inherit unwrapped; };
  meta = {
    description = "Worktree-based development environment for coding agents";
    homepage = "https://www.onorca.dev/";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "orca-ide-gui";
    platforms = [ "x86_64-linux" ];
  };
}
