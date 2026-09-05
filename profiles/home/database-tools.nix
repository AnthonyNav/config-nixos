{ pkgs, ... }:

{
  # Clientes solamente: conectan a servicios locales o remotos sin iniciar una
  # base de datos en cada workstation.
  home.packages = with pkgs; [
    dbeaver-bin
    # Beekeeper Studio 6.0.5 is marked insecure in the pinned Nixpkgs
    # (bundled EOL Electron). Keep the other clients; do not bypass that check.
    mysql-workbench
    usql
  ];
}
