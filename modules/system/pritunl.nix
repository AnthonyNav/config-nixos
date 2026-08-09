{ pkgs, ... }:

{
  # Cliente Pritunl (VPN corporativa/personal) reproducible: nixpkgs ya trae
  # un solo paquete con CLI (`pritunl-client`), el daemon privilegiado
  # (`pritunl-client-service`, con openvpn/wireguard-tools ya envueltos en su
  # PATH) y la GUI Electron (`pritunl-client-electron`, con su .desktop +
  # iconos) — compilado desde fuente, nada de AppImage descargado a mano.
  # Reemplaza el viejo hack en modules/home/zsh.nix que esperaba un AppImage
  # en ~/.local/bin (nunca se llegó a descargar).
  environment.systemPackages = [ pkgs.pritunl-client ];

  # El paquete trae su propia unidad systemd
  # (lib/systemd/system/pritunl-client.service, ExecStart =
  # pritunl-client-service). systemd.packages solo la INSTALA; hay que
  # habilitarla explícitamente para que el daemon arranque en el boot y la
  # CLI/GUI puedan levantar túneles sin tener que arrancarlo a mano.
  systemd.packages = [ pkgs.pritunl-client ];
  systemd.services."pritunl-client".wantedBy = [ "multi-user.target" ];
}
