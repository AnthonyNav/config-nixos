{ lib, pkgs, ... }:

{
  # Wallpapers estáticos que combinan con los esquemas de color que ya trae
  # Caelestia empaquetados (catppuccin, nord, dracula, gruvbox, tokyonight,
  # solarized, onedark...). Fuente: yukazakiri/themed-wallpapers, ~1100
  # wallpapers organizados en carpetas por paleta — coincide casi 1:1 con los
  # esquemas de caelestia-cli. Se descargan solo la primera vez (idempotente:
  # si la carpeta del tema ya existe, no se vuelve a clonar) hacia subcarpetas
  # dentro de ~/Pictures/Wallpapers/. El selector visual de wallpapers de
  # Caelestia (panel/launcher, ver modules/home/caelestia.nix y README.md,
  # "Wallpapers") lista y navega esta estructura por subcarpetas directamente.
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
}
