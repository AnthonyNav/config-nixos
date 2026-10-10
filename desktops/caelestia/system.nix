{ ... }:

{
  imports = [
    ../../modules/system/display-manager.nix
    ../../modules/system/keyboard-interaction.nix
  ];

  # Caelestia reemplaza el applet de Blueman y consulta energía mediante UPower.
  services.blueman.enable = false;
  services.upower.enable = true;
}
