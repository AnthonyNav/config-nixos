{ pkgs, ... }:

{
  programs.zsh.initContent = ''
    # Blender standalone debe ganar al fallback CPU-only de nixpkgs, pero solo
    # en hosts que importan la suite creativa con NVIDIA.
    export PATH="$HOME/.local/opt/blender:$PATH"

    resolve() {
      gpu-launch env QT_QPA_PLATFORM=xcb davinci-resolve "$@"
    }

    blender-gpu() {
      gpu-launch env LD_LIBRARY_PATH="/run/opengl-driver/lib:$LD_LIBRARY_PATH" "$HOME/.local/opt/blender/blender" "$@"
    }

    to-dnxhr() {
      if [ "$#" -eq 0 ]; then
        echo "Uso: to-dnxhr archivo1.mp4 [archivo2.mp4 ...]" >&2
        return 1
      fi
      local f
      for f in "$@"; do
        ffmpeg -i "$f" -c:v dnxhd -profile:v dnxhr_hq -pix_fmt yuv422p \
          -c:a pcm_s16le "''${f%.*}_dnxhr.mov"
      done
    }

    to-h264() {
      if [ "$#" -eq 0 ]; then
        echo "Uso: to-h264 master.mov" >&2
        return 1
      fi
      ffmpeg -i "$1" -c:v h264_nvenc -preset p5 -cq 19 -c:a aac -b:a 192k \
        "''${1%.*}_h264.mp4"
    }
  '';

  # Los .desktop y las funciones de Zsh comparten este ejecutable. PRIME se
  # detecta al ejecutar para conservar el mismo módulo en victus y desktop.
  home.packages = [
    (pkgs.writeShellScriptBin "gpu-launch" ''
      if command -v nvidia-offload >/dev/null 2>&1; then
        exec nvidia-offload "$@"
      else
        exec "$@"
      fi
    '')
  ];
}
