{ lib, pkgs, ... }:

{
  # Official Blender Foundation build with precompiled CUDA/OptiX kernels.
  # Keep the version and checksum pinned; Home Manager refreshes the local copy
  # only when the managed version changes.
  home.activation.fetchBlenderStandalone =
    let
      blenderVersion = "5.2.1";
      blenderSha256 = "a31f524fa99a527d3d52b7f5aaa68c34e1a19d5a1c9473f79c5cc610fd5b10e9";
      blenderUrl = "https://download.blender.org/release/Blender5.2/blender-${blenderVersion}-linux-x64.tar.xz";
    in
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      blender_dir="$HOME/.local/opt/blender"
      version_file="$blender_dir/.managed-version"
      current_version=""
      if [ -r "$version_file" ]; then
        current_version="$(cat "$version_file")"
      fi

      if [ "$current_version" != "${blenderVersion}" ] || [ ! -x "$blender_dir/blender" ]; then
        tmp="$(mktemp -d)"
        archive="$tmp/blender.tar.xz"

        if $DRY_RUN_CMD ${pkgs.curl}/bin/curl -fsSL "${blenderUrl}" -o "$archive"; then
          echo "${blenderSha256}  $archive" > "$tmp/checksum"
          if ${pkgs.coreutils}/bin/sha256sum -c "$tmp/checksum" >/dev/null 2>&1; then
            $DRY_RUN_CMD ${pkgs.gnutar}/bin/tar -xJf "$archive" -C "$tmp"
            $DRY_RUN_CMD mkdir -p "$HOME/.local/opt"
            $DRY_RUN_CMD rm -rf "$blender_dir"
            $DRY_RUN_CMD mv "$tmp/blender-${blenderVersion}-linux-x64" "$blender_dir"
            $DRY_RUN_CMD ${pkgs.coreutils}/bin/printf '%s\n' "${blenderVersion}" > "$version_file"
          else
            echo "Blender checksum verification failed." >&2
            rm -rf "$tmp"
            exit 1
          fi
        else
          echo "Blender download failed." >&2
          rm -rf "$tmp"
          exit 1
        fi

        rm -rf "$tmp"
      fi
    '';
}
