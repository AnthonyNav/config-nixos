{ lib, pkgs, ... }:

let
  # Fondo animado para el modo claro (ver modules/home/theme-wallpaper.nix y
  # caelestia-scheme.nix). "Clouds.gif" de Wikimedia Commons: dominio
  # público/CC, URL estable de upload.wikimedia.org, fijado por SHA-256 igual
  # que blender-gpu.nix. Es un placeholder genérico (no combina
  # temáticamente con el fondo.gif oscuro, que es un gif anime elegido a
  # mano) — para reemplazarlo por gusto propio, basta con dejar tu propio
  # archivo en ~/Pictures/Wallpapers/fondo-light.gif (este script NO lo
  # sobreescribe si ya existe, igual que respeta fondo.gif).
  lightWallpaperUrl = "https://upload.wikimedia.org/wikipedia/commons/2/2f/Clouds.gif";
  lightWallpaperSha256 = "fb52b293e5213f5ae94e2b0dc399927ef3efc3578a6307f668b651c11d552324";
in
{
  # Wallpapers adicionales que combinan con los esquemas de color que ya trae
  # Caelestia empaquetados (catppuccin, nord, dracula, gruvbox, tokyonight,
  # solarized, onedark...). Fuente: yukazakiri/themed-wallpapers, ~1100
  # wallpapers organizados en carpetas por paleta — coincide casi 1:1 con los
  # esquemas de caelestia-cli. Se descargan solo la primera vez (idempotente:
  # si la carpeta del tema ya existe, no se vuelve a clonar) hacia subcarpetas
  # dentro de ~/Pictures/Wallpapers/, SIN tocar fondo.gif (el wallpaper animado
  # actual, que vive suelto en la raíz de esa misma carpeta). El selector de
  # wallpapers de Caelestia soporta esta estructura por subcarpetas.
  home.activation.fetchThemedWallpapers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    wallpapers_dir="$HOME/Pictures/Wallpapers"
    git_bin="${pkgs.git}/bin/git"

    for tema in catppuccin nord dracula gruvbox tokyo-dark tokyo-moon tokyo-storm solarized onedark; do
      dest="$wallpapers_dir/$tema"
      if [ ! -d "$dest" ]; then
        tmp="$(mktemp -d)"
        if $DRY_RUN_CMD "$git_bin" clone --quiet --depth 1 --filter=blob:none --sparse \
             https://github.com/yukazakiri/themed-wallpapers "$tmp" 2>/dev/null; then
          $DRY_RUN_CMD "$git_bin" -C "$tmp" sparse-checkout set "$tema" 2>/dev/null || true
          if [ -d "$tmp/$tema" ]; then
            $DRY_RUN_CMD mkdir -p "$wallpapers_dir"
            $DRY_RUN_CMD mv "$tmp/$tema" "$dest"
          fi
        fi
        rm -rf "$tmp"
      fi
    done
  '';

  # Fondo del modo claro (ver comentario arriba). Mismo idioma que
  # blender-gpu.nix: idempotente (no re-descarga si ya existe) y verificado
  # por checksum antes de instalarlo.
  home.activation.fetchLightWallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    dest="$HOME/Pictures/Wallpapers/fondo-light.gif"

    if [ ! -f "$dest" ]; then
      tmp="$(mktemp -d)"
      archive="$tmp/fondo-light.gif"

      if $DRY_RUN_CMD ${pkgs.curl}/bin/curl -fsSL "${lightWallpaperUrl}" -o "$archive"; then
        echo "${lightWallpaperSha256}  $archive" > "$tmp/checksum"
        if ${pkgs.coreutils}/bin/sha256sum -c "$tmp/checksum" >/dev/null 2>&1; then
          $DRY_RUN_CMD mkdir -p "$HOME/Pictures/Wallpapers"
          $DRY_RUN_CMD mv "$archive" "$dest"
        fi
      fi

      rm -rf "$tmp"
    fi
  '';
}
