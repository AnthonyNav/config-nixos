{
  pkgs,
  lib ? pkgs.lib,
}:
let
  revision = "371aa6df56880643da57b30da936e9812fb0ec66";
  source = pkgs.fetchzip {
    url = "https://github.com/google/artemis/archive/${revision}.tar.gz";
    sha256 = "1y67r0bbkbqpx37k1qn24byz9fgkm87wc0i3ihjay0pgz8ga0f7v";
  };
  python = pkgs.python312;
  runtimeId = builtins.substring 0 16 (builtins.hashString "sha256" "${source}:${python}");
  config = pkgs.writeText "fleet-artemis-runtime.json" (
    builtins.toJSON {
      inherit revision runtimeId;
      source = toString source;
      python = "${python}/bin/python3";
      uv = "${pkgs.uv}/bin/uv";
      libraryPath = lib.makeLibraryPath [
        pkgs.stdenv.cc.cc.lib
        pkgs.zlib
        pkgs.glib
        pkgs.libGL
        pkgs.libxcb
        pkgs.libX11
        pkgs.libXext
        pkgs.libSM
        pkgs.libICE
      ];
      binPath = lib.makeBinPath [
        pkgs.android-tools
        pkgs.scrcpy
        pkgs.ffmpeg
        pkgs.git
      ];
    }
  );
in
pkgs.writeShellApplication {
  name = "fleet-artemis";
  text = ''exec ${python}/bin/python3 ${../scripts/artemis.py} ${config} "$@"'';
  passthru = { inherit source revision config; };
  meta.description = "Opt-in pinned Artemis runtime; explicit preparation, no global installer";
}
