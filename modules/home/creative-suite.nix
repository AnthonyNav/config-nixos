{
  lib,
  pkgs,
  hostFeatures,
  ...
}:

{
  # Stack de creación 3D/video para hosts con NVIDIA. Victus usa PRIME offload;
  # desktop usa su RTX como GPU principal. La base diaria no importa este módulo.
  imports = [
    ./blender-gpu.nix # binario standalone con CUDA/OptiX, requiere NVIDIA dedicada
    ./creative-shell.nix
    ./gpu-launchers.nix # overrides .desktop para nvidia-offload (Resolve/Blender)
  ];

  assertions = [
    {
      assertion =
        hostFeatures.creativeNvidia
        && lib.elem hostFeatures.graphics [
          "nvidia"
          "nvidia-prime"
        ];
      message = "creative-suite requires an NVIDIA host capability.";
    }
  ];

  # --- CREACIÓN 3D / VIDEO ---
  # Editor NLE gratuito de Resolve NO decodifica/exporta H.264/H.265 en
  # Linux (limitación de licencia, no del hardware). Flujo: ingesta con
  # `to-dnxhr` (zsh.nix) antes de importar, entrega con `to-h264` al final.
  # Si esto molesta a futuro, la salida es cambiar este atributo por
  # davinci-resolve-studio (~$295, pago único, sí trae esos códecs).
  home.packages = with pkgs; [
    davinci-resolve
    kdePackages.kdenlive # NLE de respaldo: sí ingesta H.264 directo (NVENC), sin transcodificar
    blender # respaldo CPU-only/reproducible; el binario con CUDA/OptiX real es
    # el standalone en ~/.local/opt/blender (ver modules/home/blender-gpu.nix
    # y creative-shell.nix), que gana en PATH.
    krita # pintura/raster — equivalente Photoshop
    gimp # edición de foto — equivalente Photoshop
    inkscape # vectorial — equivalente Illustrator
    # natron (compositor nodal alternativo a Fusion) omitido: marcado "broken"
    # en el pin actual de nixpkgs-unstable. Fusion (dentro de Resolve) cubre
    # ese rol; revisar en el futuro si upstream lo repara.
    ffmpeg-full # trae NVENC habilitado; usado por to-dnxhr/to-h264
    nvidia-vaapi-driver
  ];
}
