# Review: feat/workstation-layers

## Summary

Auditoría local del refactor de workstations, realizada el 2026-10-03.
No quedan hallazgos Blocker/Major verificados en los contratos y flujos probados.
La aceptación física sigue pendiente: compilar no prueba arranque, gráficos,
suspensión, audio ni autenticación. No se activó ni desplegó esta rama.

## Change Surface

Modified: 52 archivos. Added: 20 archivos. Deleted: 25 archivos.
Conteo del diff completo contra main, incluyendo este informe.

Áreas principales: inventario/composición, perfiles de Home Manager, módulos
diarios/dotfiles, monitores por eventos, retiro de ThinkPad/laboratorio/servidor,
política de recursos, dependencias, pruebas y documentación.

Integraciones: NixOS/Home Manager, Hyprland IPC y systemd user, Caelestia,
SSH/Tailscale/Syncthing e identidades existentes. No hay migración de bases de
datos ni llamadas de publicación de política Tailscale. El inventario deriva
dos sistemas y dos activaciones Home; el instalador permanece separado.

Los archivos de hardware, discos y boot de Desktop/Victus no tienen cambios.
La actualización de nixpkgs sí cambia el kernel/driver construido: no confundir
preservar sus opciones con haber validado el nuevo driver en hardware.

## Minor Issues

### Minor 1 - Deuda de lint preexistente y estilo

Ubicación: `modules/home/theme-sync.nix:4`,
`hosts/desktop/hardware-configuration.nix:7` y
`hosts/victus/hardware-configuration.nix:7`.

Deadnix global detecta tres argumentos `pkgs` sin usar en archivos sin cambios.
Deadnix sobre los archivos Nix añadidos/modificados pasa. Statix global conserva
35 advertencias de estilo (inherit, atributos repetidos y paréntesis), sin
diagnóstico semántico demostrado. No se declara el repositorio libre de lint.
Resolver esta deuda en un seguimiento sin editar hardware generado por estilo.

### Minor 2 - Wallpapers fuera del lock y descarga repetida

Ubicación: `modules/home/wallpapers.nix`, sin cambios en este PR.

La primera activación clona el HEAD remoto una vez por tema faltante; el lock
de Nix no fija esos assets. Las activaciones siguientes reutilizan las carpetas
existentes. Seguimiento recomendado: una sola descarga de una revisión/hash
verificados, preservando wallpapers personales. No atribuir ahorro de red ni
reproducibilidad de estos assets al refactor actual.

## What's Working Well

- Un Home diario compartido con perfiles explícitos; una fixture no desplegable
  comprueba la base sin NVIDIA, creatividad, virtualización ni SDKs. Se rechazan
  tipos de host/perfiles inválidos y creatividad sin la capacidad NVIDIA.
- Paquetes y dotfiles de usuario en Home Manager, servicios/drivers en NixOS,
  entornos específicos en proyectos. Neovim ejecuta su Lua en headless; Starship
  conserva los settings previos y se valida contra el TOML declarado.
- Un solo escritor de monitores. La selección reconoce identidades físicas y
  modos anunciados; el fallback conserva modo/escala, ignora el foco y funciona
  con pantalla interna y externos desconocidos. No habilita pantallas apagadas.
- El watcher suscribe eventos antes de consultar el estado inicial, agrupa
  ráfagas y limita reintentos. El ajuste manual valida antes de pausar el
  automatismo y lo recupera si falla IPC y antes estaba activo.
- Se preservan rutas de perfiles Firefox, archivos mutables de Caelestia,
  identidades y SDKs todavía usados por proyectos. No se migran credenciales
  ni sesiones al store y no se cambian los stateVersion existentes.
- La compilación detectó y permitió corregir SonoBus/GCC 16 con C++17 explícito,
  sin eliminar la aplicación ni retroceder el toolchain. Las decisiones de
  actualización y sus fuentes están en [workstation-research.md](workstation-research.md).

## Validación local

Puerta de salida requerida antes de publicar: formato, evaluación, checks con
build, los cuatro outputs y escaneo de secretos, sobre el estado final.

```sh
nix fmt
nix flake check --no-build --no-write-lock-file
nix flake check --no-write-lock-file
nix build --max-jobs 1 --cores 2 --no-link --print-build-logs --no-write-lock-file \
  .#nixosConfigurations.desktop.config.system.build.toplevel \
  .#nixosConfigurations.victus.config.system.build.toplevel \
  '.#homeConfigurations."anthony@desktop".activationPackage' \
  '.#homeConfigurations."anthony@victus".activationPackage'
```

Los 17 checks nombrados abarcan: AI environment/tools, CI workflows,
development-path, dotfiles, fleet-policy, formatting, identity-policy,
manual-monitors, monitor-layout, network-endpoints, nix-config,
project-environments, resource-policy, syncthing-policy, tailscale-policy y
workstation-policy. El número de derivaciones que muestra Nix no equivale al
número de suites.

La suite de monitores contiene 13 pruebas: layouts conocidos de dos/tres
externos, panel interno, fallback/escala, identidades duplicadas, modos no
soportados, dry-run de sólo lectura, idempotencia, errores IPC y eventos
fragmentados/debounce. Las cuatro pruebas de set-monitor usan ejecutables
simulados; no modifican la sesión real. Los checks existentes ejercitan también
reconciliación AI, comandos de mantenimiento y políticas de red/identidad.

ShellCheck y Actionlint pasan. Gitleaks analiza el árbol y el historial Git con
redacción; sin secretos detectados. Se comprueban además enlaces Markdown
locales y que los outputs evaluados finales existan realmente en el store.
Un escaneo limpio no sustituye revisar el contenido ni revocar accesos externos.

En GitHub, `flake-check.yml` corre checks y planes de build derivados del
inventario. Los builds completos de `full-build.yml` son workflow_dispatch;
no se afirma que el PR los ejecute automáticamente. Los cuatro builds locales
son parte de esta puerta de salida.

## Risk Assessment

Merge risk: MEDIUM por alcance compartido y actualización de kernel/driver.
Usuarios afectados: Anthony en Desktop y Victus; ThinkPad deja de ser un target
soportado. No se conoce aún el hardware del equipo de reemplazo.

Rollback: revertir los commits mediante un PR a main y construir nuevamente
los outputs. Si un despliegue autorizado posterior falla, inspeccionar las
generaciones y usar el procedimiento documentado de rollback; nunca activar
esta rama para probar. Conservar generaciones y respaldos antes del rollout.
El rollback de Nix no restaura logs expirados por la nueva retención de journal,
ni cambios manuales de servicios externos.

Datos: este trabajo no borra proyectos, discos de VM, volúmenes, carpetas
Syncthing ni configuraciones personales. El futuro despliegue modifica peers
administrados de Syncthing y retira redes/servicios específicos del laboratorio.
Revisar guests y carpetas compartidas antes de aplicarlo. La baja física del
equipo laboral, nodos Tailscale, Serve/grants antiguos y sesiones externas
requieren acciones separadas y autorizadas.

Recommended testing, sólo después de main revisado/publicado y un despliegue
expresamente autorizado:

- [ ] Arranque, sesión Caelestia, cierre/bloqueo y Wi-Fi en ambos equipos.
- [ ] Tres pantallas del escritorio; portátil con dos externos; sólo panel
  interno; periféricos desconocidos; reconectar/dock/DPMS/suspensión.
- [ ] Refresh/rotación reales, cambio manual y recuperación de monitor-auto;
  escritorio usable si IPC falla. Ver [monitors.md](monitors.md).
- [ ] NVIDIA directo y PRIME, Blender/Resolve y carga GPU en Docker, sin asumir
  que capacidades declaradas equivalen a un workload activo.
- [ ] Firefox y perfiles existentes; Kitty/Neovim/Starship; audio, mpv/SonoBus,
  IDEs y proyectos todavía dependientes de SDKs globales.
- [ ] SSH/Tailscale, Syncthing entre Desktop/Victus e input sharing; revisar
  dispositivos/carpetas administrados sin borrar sus archivos.
- [ ] VM local sin autostart; inventariar/rediseñar o retirar guests del antiguo
  laboratorio conservando sus discos.
- [ ] Medir memoria/swap/CPU, logs y store sin cargas comparables de build;
  no prometer ahorro de RAM. Ver [resource-policy.md](resource-policy.md).
