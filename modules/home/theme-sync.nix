{
  lib,
  ...
}:

{
  xdg.configFile."caelestia/templates/hyprland-colors.conf".text = ''
    general {
      col.active_border = rgba({{ primary.hex }}ff) rgba({{ secondary.hex }}ff) 45deg
      col.inactive_border = rgba({{ outlineVariant.hex }}ff)
    }
  '';
  xdg.configFile."caelestia/templates/rofi.rasi".text = ''
    * {
      bg-col: #{{ surface.hex }};
      border-col: #{{ primary.hex }};
      selected-col: #{{ surfaceContainer.hex }};
      text-col: #{{ onSurface.hex }};
      accent-text: #{{ onPrimary.hex }};
    }
    ${builtins.readFile ../../dotfiles/rofi/layout.rasi}
  '';
  xdg.configFile."caelestia/templates/starship.toml".text =
    let
      palette = (import ./catppuccin-palette.nix).mocha;
      # Semantic/terminal roles exist in every native scheme, including saved
      # palettes from before this PR. Catppuccin-specific names do not.
      roles = {
        red = "error";
        green = "term2";
        yellow = "term3";
        blue = "term4";
        mauve = "secondary";
        lavender = "primary";
      };
    in
    lib.replaceStrings (map (name: palette.${name}) (builtins.attrNames roles)) (map (
      name: "{{ ${roles.${name}}.hex }}"
    ) (builtins.attrNames roles)) (builtins.readFile ../../dotfiles/starship/starship.toml);
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

  # personalizeCaelestia seeds every rendered file after linkGeneration, using
  # the saved user scheme or Mocha on a new machine. No activation download.
}
