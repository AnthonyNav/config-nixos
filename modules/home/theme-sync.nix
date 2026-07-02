{ config, lib, pkgs, ... }:

{
  # Motor de sincronización de temas: kitty lee sus colores DEL esquema activo
  # de Caelestia (en vez de tener su propia paleta catppuccin estática y
  # desincronizada). Caelestia trae un sistema de plantillas tipo pywal ya
  # integrado en su CLI: cualquier archivo en ~/.config/caelestia/templates/
  # con placeholders {{ colorName.hex }} se renderiza a
  # ~/.local/state/caelestia/theme/<archivo> cada vez que corres
  # `caelestia scheme set ...` (o eliges Scheme/Variant desde el launcher).
  xdg.configFile."caelestia/templates/kitty-colors.conf".text = ''
    background #{{ surface.hex }}
    foreground #{{ onSurface.hex }}
    cursor #{{ primary.hex }}
    cursor_text_color #{{ surface.hex }}
    selection_background #{{ primary.hex }}
    selection_foreground #{{ surface.hex }}

    color0  #{{ term0.hex }}
    color1  #{{ term1.hex }}
    color2  #{{ term2.hex }}
    color3  #{{ term3.hex }}
    color4  #{{ term4.hex }}
    color5  #{{ term5.hex }}
    color6  #{{ term6.hex }}
    color7  #{{ term7.hex }}
    color8  #{{ term8.hex }}
    color9  #{{ term9.hex }}
    color10 #{{ term10.hex }}
    color11 #{{ term11.hex }}
    color12 #{{ term12.hex }}
    color13 #{{ term13.hex }}
    color14 #{{ term14.hex }}
    color15 #{{ term15.hex }}
  '';

  # Bootstrap: la primera vez que se activa este perfil (o en cualquier host
  # nuevo), ~/.local/state/caelestia/theme/kitty-colors.conf todavía no existe
  # (kitty fallaría al incluir un archivo inexistente). Se genera una sola vez
  # con el esquema por defecto; en adelante el usuario lo controla con
  # `caelestia scheme set`. No se repite en cada switch (idempotente).
  home.activation.bootstrapCaelestiaTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    state_file="$HOME/.local/state/caelestia/theme/kitty-colors.conf"
    if [ ! -f "$state_file" ]; then
      $DRY_RUN_CMD ${config.programs.caelestia.cli.package}/bin/caelestia scheme set \
        --name catppuccin --flavour mocha --mode dark || true
    fi
  '';
}
