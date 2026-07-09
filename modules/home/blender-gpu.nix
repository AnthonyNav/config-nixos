{ lib, pkgs, ... }:

{
  # Blender standalone (build oficial de blender.org). El paquete `blender` de
  # nixpkgs (ver home.nix) se compila SIN backend GPU de Cycles en absoluto
  # (confirmado en su derivación: WITH_CYCLES_CUDA_BINARIES=FALSE,
  # WITH_CYCLES_DEVICE_OPTIX=FALSE) — Preferences > System solo lista
  # "None"/"CUDA" y CUDA no encuentra ningún dispositivo, aunque la RTX 4050
  # esté perfectamente sana (`nvidia-smi` la ve bien). Habilitar
  # `cudaSupport` en nixpkgs recompilaría Blender entero con el toolchain de
  # NVIDIA (nvcc) sin cache binario por ser unfree — 30-90+ min y varios GB
  # extra. El build oficial de Blender Foundation trae esos kernels
  # precompilados: mismo patrón que opencode/claude (binario standalone como
  # primario, el paquete de Nix como respaldo reproducible/CPU-only).
  #
  # Versión y hash fijados a mano (nada de "latest" silencioso). Para subir
  # de versión: cambiar blenderVersion/blenderSha256 abajo (hash real,
  # publicado por blender.org en blender-X.Y.Z.sha256) y borrar
  # ~/.local/opt/blender para forzar la re-descarga en el siguiente
  # `hm-switch`.
  home.activation.fetchBlenderStandalone =
    let
      blenderVersion = "5.1.2";
      blenderSha256 = "aaccb355f50183979b698bcce7467103a76261b5fa59f4972295842662a285fb";
      blenderUrl = "https://download.blender.org/release/Blender5.1/blender-${blenderVersion}-linux-x64.tar.xz";
    in
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      blender_dir="$HOME/.local/opt/blender"

      if [ ! -x "$blender_dir/blender" ]; then
        tmp="$(mktemp -d)"
        archive="$tmp/blender.tar.xz"

        if $DRY_RUN_CMD ${pkgs.curl}/bin/curl -fsSL "${blenderUrl}" -o "$archive"; then
          echo "${blenderSha256}  $archive" > "$tmp/checksum"
          if ${pkgs.coreutils}/bin/sha256sum -c "$tmp/checksum" >/dev/null 2>&1; then
            $DRY_RUN_CMD ${pkgs.gnutar}/bin/tar -xJf "$archive" -C "$tmp"
            $DRY_RUN_CMD mkdir -p "$HOME/.local/opt"
            $DRY_RUN_CMD rm -rf "$blender_dir"
            $DRY_RUN_CMD mv "$tmp/blender-${blenderVersion}-linux-x64" "$blender_dir"
          fi
        fi

        rm -rf "$tmp"
      fi
    '';
}
