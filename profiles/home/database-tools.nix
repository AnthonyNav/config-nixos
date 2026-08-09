{ pkgs, ... }:

{
  # Clientes solamente: conectan a servicios locales o remotos sin iniciar una
  # base de datos en cada workstation.
  home.packages = with pkgs; [
    dbeaver-bin
    beekeeper-studio
    mysql-workbench
    usql
  ];
}
