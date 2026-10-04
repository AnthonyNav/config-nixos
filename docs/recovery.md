# Recuperación y migraciones de seguridad

La flota administrada contiene Desktop y Victus. ThinkPad está retirada: no es
un destino de build, despliegue, SSH administrado o sincronización de la flota.
Sus datos se conservan. La reconciliación elimina únicamente declaraciones de
pares/carpetas de la flota; no elimina sus rutas ni archivos locales. Revocar
identidades externas requiere su propio alcance explícito.

## Respaldo cifrado preparado, desactivado

`fleet.backup.enable` es `false` en toda la flota. No se ha elegido un destino y
este PR no crea repositorios ni credenciales. Syncthing replica cambios y
eliminaciones; una generación anterior de NixOS recupera configuración, no los
documentos borrados. El versionado de Syncthing es local y el reconciliador lo
conserva en vez de restablecerlo cada diez minutos.

Cuando exista un disco externo, NAS o servicio remoto, revisar en un PR la
configuración por host:

```nix
fleet.backup = {
  enable = true;
  paths = [ "/home/anthony/Documents" "/home/anthony/projects" ];
  repositoryFile = "/var/lib/fleet-backup/repository";
  passwordFile = "/var/lib/fleet-backup/password";
  # environmentFile = "/var/lib/fleet-backup/environment";
};
```

Crear esos archivos **localmente**, con directorio 0700 y archivos 0600 propiedad
del usuario. El primero contiene la dirección del repositorio Restic; el segundo
su contraseña. Credenciales remotas pueden usar `environmentFile`. Nunca usar
archivos Nix, `writeText`, `.env` versionados o rutas de `/nix/store` para secretos.
Cada equipo necesita su destino/identidad de respaldo; no sincronizar la única
copia de la contraseña junto con los datos que protege.

La inicialización automática está deshabilitada: antes de `restic-fleet-personal
init`, confirmar que el disco esperado está montado, que la dirección es correcta
y que existe una copia de recuperación de la contraseña. Para un disco externo,
añadir dependencias/condiciones de montaje al servicio en ese mismo PR para que
no escriba en el disco interno cuando el externo esté ausente. Un destino remoto
necesita sus permisos y credenciales reales. El módulo rechaza habilitación sin
carpetas explícitas y rutas de credenciales dentro del store o del checkout.

El timer diario conserva siete copias diarias, cuatro semanales y seis mensuales;
excluye cachés, `node_modules` y `.direnv`. Un timer semanal revisa integridad y
lee un 5% de los datos. CPU/IO tienen menor prioridad. Cambiar carpetas o retención
requiere revisar el contenido esperado antes de ejecutar poda.

## Ensayo de restauración

El check `backup-restore` crea un repositorio cifrado temporal, respalda un
documento, modifica el original, valida todos los datos y restaura a una ruta
distinta, comprobando su contenido. No toca archivos del usuario ni un servicio
externo. Ese check demuestra el mecanismo; el destino real debe pasar su propio
ensayo después de configurarse.

Con el módulo habilitado y el destino accesible:

```sh
restic-fleet-personal snapshots
restic-fleet-personal check --read-data
restic-fleet-personal restore <snapshot-id> --target /home/anthony/restore-verification
```

Usar un directorio nuevo, abrir/comparar varios archivos y registrar fecha,
snapshot y resultado. No restaurar sobre el home activo para el ensayo. Repetir
tras cambiar destino, credenciales o conjuntos de datos. Revisar los servicios
`restic-backups-fleet-personal` y `restic-backups-fleet-integrity` y sus journals.

## Docker sin privilegios

`fleet.containers.rootless` está preparado como opción, con fixture de evaluación,
pero permanece desactivado. El Docker actual y el grupo `docker` conservan acceso
equivalente a root. Una migración cambia sockets, almacenes de imágenes/volúmenes,
UID/GID, red y acceso GPU; habilitarla sin mover/verificar datos puede hacer que
los proyectos parezcan vacíos.

Inventariar contenedores, bind mounts, volúmenes y proyectos Compose, respaldarlos
y comprobar la recuperación. Probar en Victus primero Docker/CDI con RTX, red y
permisos del proyecto. Después revisar `fleet.containers.rootless = true`: elimina
el daemon y grupo rootful administrados, configura el socket de usuario y evita
arrancar el daemon al iniciar sesión. Se inicia explícitamente con `systemctl
--user start docker`. No se borran datos de `/var/lib/docker`; para recuperar la
configuración previa, revertir la opción y revisar el estado antes de arrancar
el daemon anterior.

Referencias: [Docker rootless](https://docs.docker.com/engine/security/rootless/)
y [privilegios del grupo docker](https://docs.docker.com/engine/install/linux-postinstall/).

## Cifrado de discos

Desktop y Victus todavía no declaran LUKS para raíz/home. El swap cifrado de
Victus no protege documentos persistentes. Este PR no cambia particiones, UUID,
arranque ni cifrado de discos.

La migración requiere inventario de discos y particiones, respaldo verificado,
medio de rescate arrancable y almacenamiento separado de las claves. Probar
primero un disco/VM de ensayo y luego Victus: reinstalar/restaurar sobre un volumen
LUKS planificado es más revisable que cifrar en caliente sin recuperación probada.
Actualizar únicamente el módulo del host con los UUID reales, comprobar arranque,
desbloqueo, suspensión y recuperación; después repetir en Desktop. No habilitar
hibernación ni publicar claves para completar esa migración.
