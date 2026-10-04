{
  config,
  lib,
  pkgs,
  ...
}:
let
  policy = import ./caelestia-personalization-policy.nix { inherit lib; };
  policyFile = pkgs.writeText "desktop-appearance-policy.json" (builtins.toJSON policy);
  desktopPreset = pkgs.writeShellApplication {
    name = "desktop-preset";
    runtimeInputs = [
      pkgs.libnotify
      pkgs.python3
      pkgs.hyprland
      config.programs.caelestia.cli.package
    ];
    text = ''
      if ! python3 ${../../scripts/desktop-appearance.py} --policy ${policyFile} "$@"; then
        if [ "''${1:-}" = "apply" ]; then
          notify-send -u critical "Personalización" "No se pudo aplicar el perfil; revisa desktop-preset en la terminal" || true
        fi
        exit 1
      fi
      if [ "''${1:-}" = "apply" ]; then
        notify-send "Personalización" "Perfil aplicado: ''${2:-}" || true
      fi
    '';
  };
in
{
  home.packages = [
    desktopPreset
    (pkgs.writeShellApplication {
      name = "night-light-toggle";
      runtimeInputs = [
        pkgs.systemd
        pkgs.libnotify
      ];
      text = ''
        if systemctl --user is-active --quiet wlsunset.service; then
          systemctl --user stop wlsunset.service
          notify-send "Luz cálida" "Desactivada"
        else
          systemctl --user start wlsunset.service
          notify-send "Luz cálida" "Activada (automática)"
        fi
      '';
    })
  ];
  # Mutable user choices are merged, never linked to the store or overwritten
  # by a switch. Only an explicit desktop-preset apply changes existing values.
  home.activation.personalizeCaelestia =
    lib.hm.dag.entryAfter
      [
        "bootstrapCaelestiaShellConfig"
        "linkGeneration"
      ]
      ''
        $DRY_RUN_CMD ${desktopPreset}/bin/desktop-preset bootstrap
      '';
  # Override Home Manager's static config path: Caelestia owns this output.
  home.sessionVariables.STARSHIP_CONFIG = lib.mkForce "${config.xdg.stateHome}/caelestia/theme/starship.toml";
}
