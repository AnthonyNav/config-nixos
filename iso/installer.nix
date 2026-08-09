{ inputs, ... }:

{
  # SSH funcional desde el primer arranque del live USB: misma llave que ya
  # autoriza a este equipo en modules/system/core.nix, para poder manejar
  # toda la instalación de un host nuevo (ej. thinkpad) por SSH desde otra
  # máquina, sin tocar el teclado ni configurar nada a mano. El ISO oficial de
  # NixOS solo trae password vacío (root/nixos) — services.openssh ya está
  # habilitado por profiles/installation-device.nix, pero sin una llave
  # autorizada no hay forma de entrar por SSH sin antes correr `passwd` en la
  # consola local.
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMSZBAoRb/gxevgsIFbtcg/hPx+gvv0tfj25KtubL0xd anthonydevxp@gmail.com"
  ];

  # Copia de este mismo repo (el checkout que construyó esta ISO), disponible
  # desde el primer segundo en /etc/nixos-config — nada de clonar a mano ni
  # depender de internet en el instalador. Vive en el store (solo lectura):
  # antes de generar hardware-configuration.nix o correr nixos-install, se
  # copia a un sitio escribible:
  #   cp -r /etc/nixos-config ~/nixos-config && cd ~/nixos-config
  environment.etc."nixos-config".source = inputs.self;
}
