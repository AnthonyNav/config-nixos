{ pkgs, username, ... }:

{
  # Perfil opcional para desarrollo local. No se importa por defecto: los
  # clientes del perfil database-tools pueden conectarse a servicios remotos.
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    ensureUsers = [
      {
        name = username;
        ensurePermissions."*.*" = "ALL PRIVILEGES";
      }
    ];
  };

  environment.systemPackages = [ pkgs.mariadb ];
}
