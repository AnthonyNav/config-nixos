{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  libGL,
  libGLU,
  libx11,
  libxext,
  libxi,
  libxt,
  libxfixes,
  libxrender,
  libxxf86vm,
  libsm,
  libice,
  libxkbcommon,
  wayland,
  libdecor,
  libspnav,
  glib,
  dbus,
  zlib,
  zstd,
  libffi,
  openssl,
  ncurses,
  util-linux,
  sdl3,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "blender-standalone";
  version = "5.2.1";
  src = fetchurl {
    url = "https://download.blender.org/release/Blender5.2/blender-${finalAttrs.version}-linux-x64.tar.xz";
    sha256 = "a31f524fa99a527d3d52b7f5aaa68c34e1a19d5a1c9473f79c5cc610fd5b10e9";
  };
  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    libGL
    libGLU
    libx11
    libxext
    libxi
    libxt
    libxfixes
    libxrender
    libxxf86vm
    libsm
    libice
    libxkbcommon
    wayland
    libdecor
    libspnav
    glib
    dbus
    zlib
    zstd
    libffi
    openssl
    ncurses
    util-linux
  ];
  # Drivers come from the active generation. Other missing libraries fail.
  # OIDN also ships optional Intel/AMD modules. Their driver loaders are not
  # dependencies of this NVIDIA package; CUDA/OptiX remain available.
  autoPatchelfIgnoreMissingDeps = [
    "libcuda.so.1"
    "libnvoptix.so.1"
    "libamdhip64.so.7"
    "libze_loader.so.1"
  ];
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/blender" "$out/bin"
    cp -a . "$out/lib/blender/"
    # The vendor SDL is linked against unavailable Steam/GLES1 libraries.
    # Use Nixpkgs' ABI-compatible SDL3 rather than hiding those dependencies.
    rm "$out/lib/blender/lib"/libSDL3.so*
    ln -s ${lib.getLib sdl3}/lib/libSDL3.so.0 "$out/lib/blender/lib/libSDL3.so.0"
    makeWrapper "$out/lib/blender/blender" "$out/bin/blender" \
      --prefix LD_LIBRARY_PATH : /run/opengl-driver/lib
    ln -s blender "$out/bin/blender-standalone"
    runHook postInstall
  '';
  meta = {
    description = "Official Blender build with precompiled CUDA/OptiX kernels";
    homepage = "https://www.blender.org";
    license = [
      lib.licenses.gpl2Plus
      lib.licenses.nvidiaCudaRedist
    ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "blender";
  };
})
