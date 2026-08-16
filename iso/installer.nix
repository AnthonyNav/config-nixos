{ inputs, ... }:

{
  # SSH funcional desde el primer arranque del live USB: misma llave pública
  # que autoriza a los hosts instalados, para poder manejar toda la instalación
  # de un host nuevo por SSH desde otra máquina. La clave privada nunca forma
  # parte de este repo ni de la ISO.
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMSZBAoRb/gxevgsIFbtcg/hPx+gvv0tfj25KtubL0xd anthony@config-nixos"
  ];

  # Copia de este mismo repo (el checkout que construyó esta ISO), disponible
  # desde el primer segundo en /etc/nixos-config — nada de clonar a mano ni
  # depender de internet en el instalador. Vive en el store (solo lectura):
  # antes de generar hardware-configuration.nix o correr nixos-install, se
  # copia a un sitio escribible:
  #   cp -r /etc/nixos-config ~/nixos-config && cd ~/nixos-config
  environment.etc."nixos-config".source = inputs.self;
}
