{ pkgs, ... }:

{
  # Stack de creación 3D/video — solo para hosts con GPU dedicada capaz de
  # PRIME offload (ver flake.nix, hostExtraHomeModules). Extraído de home.nix
  # para que thinkpad/desktop (sin GPU discreta) no carguen davinci-resolve,
  # kdenlive, ffmpeg-full, blender-gpu.nix ni gpu-launchers.nix — todo ese
  # peso de build/descarga (Electron de blender-gpu incluido) no aporta nada
  # sin una dGPU real detrás. Ver README.md, sección "Edición 3D / Video".
  imports = [
    ./blender-gpu.nix   # binario standalone con CUDA/OptiX, requiere NVIDIA dedicada
    ./gpu-launchers.nix # overrides .desktop para nvidia-offload (Resolve/Blender)
  ];

  # --- CREACIÓN 3D / VIDEO (RTX 4050 vía PRIME offload, ver hosts/victus) ---
  # Editor NLE gratuito de Resolve NO decodifica/exporta H.264/H.265 en
  # Linux (limitación de licencia, no del hardware). Flujo: ingesta con
  # `to-dnxhr` (zsh.nix) antes de importar, entrega con `to-h264` al final.
  # Si esto molesta a futuro, la salida es cambiar este atributo por
  # davinci-resolve-studio (~$295, pago único, sí trae esos códecs).
  home.packages = with pkgs; [
    davinci-resolve
    kdePackages.kdenlive # NLE de respaldo: sí ingesta H.264 directo (NVENC), sin transcodificar
    blender              # respaldo CPU-only/reproducible; el binario con CUDA/OptiX real es
                          # el standalone en ~/.local/opt/blender (ver modules/home/blender-gpu.nix
                          # y zsh.nix), que gana en PATH — mismo patrón que opencode/claude.
    krita                # pintura/raster — equivalente Photoshop
    gimp                 # edición de foto — equivalente Photoshop
    inkscape             # vectorial — equivalente Illustrator
    # natron (compositor nodal alternativo a Fusion) omitido: marcado "broken"
    # en el pin actual de nixpkgs-unstable. Fusion (dentro de Resolve) cubre
    # ese rol; revisar en el futuro si upstream lo repara.
    ffmpeg-full           # trae NVENC habilitado; usado por to-dnxhr/to-h264
  ];
}
