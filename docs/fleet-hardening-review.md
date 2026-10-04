# Review: feat/fleet-hardening-catppuccin

## Summary

Revisión de contratos y cambios compartidos para Desktop y Victus, realizada el
2026-10-04. No quedan hallazgos Blocker/Major verificados en los flujos probados.
La aceptación gráfica y de GPU requiere despliegue autorizado desde main.

## Change Surface

Modified: 33 archivos. Added: 22 archivos. Deleted: 0 archivos.
Conteo contra main, incluyendo este informe.

Áreas: reconciliación Syncthing, módulos de recuperación/contenedores, paquetes
creativos, plantillas/presets/acciones Caelestia, CI, lint y documentación.
Integraciones: REST Syncthing, CLI/QML Caelestia, systemd user, Hyprland IPC,
Restic, Blender oficial, GitHub Actions y reglas de main.

ThinkPad permanece retirada y conserva sus datos. Los archivos de hardware,
discos, stateVersion, flake.lock, identidades y credenciales no cambian.
Los respaldos y Docker rootless permanecen desactivados.

## What's Working Well

- Syncthing usa PATCH para los campos administrados y POST con defaults validados
  sólo al crear objetos. Preserva versionado, pausas, límites, watcher, dispositivos
  manuales y campos de cifrado por participante. La retirada elimina declaraciones,
  no archivos. Los fallos de descubrimiento/preflight no escriben configuración.
- La extracción del parche Wi-Fi conserva exactamente el valor anterior de Nix.
  Las funciones QML realmente parcheadas se prueban con argumentos literales,
  directorios con espacios, aplicaciones de terminal y acciones internas/externas.
- Los presets mantienen preferencias ajenas a su apariencia; guardan archivos de
  forma atómica y recuperan el estado previo si la CLI falla o deja temas obsoletos.
  Una recarga fallida de Hyprland informa que el perfil sí quedó guardado.
- La prueba con la CLI real detectó y permitió corregir un hook postPatch que
  upstream no ejecutaba. Verifica la actualización de colores guardados, los tres
  perfiles y un esquema nativo distinto. Starship usa roles disponibles en todos
  esos esquemas, sin exigir nombres exclusivos de Catppuccin.
- Blender y los fondos son paquetes fijados por hash, sin descargas de activación.
  La prueba headless de Blender comprueba arranque y Cycles; las bibliotecas que
  no son loaders opcionales de GPU deben resolverse durante el build.
- Restic restaura un documento a otro directorio tras modificar el original y
  comprueba integridad/contenido. Las fixtures verifican respaldo opt-in, rootless
  sin autoinicio y la política declarada de firewall/SSH/GUI local.
- CI descubre ambos equipos desde inventario y construye sistemas y activaciones
  Home Manager. El gate agregado exige éxito de descubrimiento y de toda la matriz.
  El archivo del ruleset es una propuesta declarativa; su efecto externo se verifica
  por separado al aplicarlo en GitHub.

## Validación local

Comandos requeridos sobre el estado final:

```sh
nix fmt
nix flake check --no-build --no-write-lock-file
nix flake check --no-write-lock-file
nix build --max-jobs 1 --cores 2 --no-link --print-build-logs --no-write-lock-file \
  .#nixosConfigurations.desktop.config.system.build.toplevel \
  .#nixosConfigurations.victus.config.system.build.toplevel \
  '.#homeConfigurations."anthony@desktop".activationPackage' \
  '.#homeConfigurations."anthony@victus".activationPackage'
nix run .#gitleaks -- dir --redact --no-banner .
nix run .#gitleaks -- git --redact --no-banner
```

La flota tiene 25 checks, incluidos los nueve casos de Syncthing y once casos de
apariencia. Se ejecutan Statix/Deadnix con exclusiones explícitas para hardware
generado; Statix permite la repetición de namespaces habitual en módulos NixOS.

## Risk Assessment

Merge risk: MEDIUM. Afecta la sesión gráfica y los lanzadores de ambos equipos.
No se activó la rama ni se ejecutaron migraciones de datos o discos.

Rollback: revertir el PR mediante main y actualizar desde esa revisión. Los
archivos personales y las copias locales antiguas se conservan. Para un preset,
seleccionar el anterior o revisar sus copias `.appearance-backup`; los ajustes
mutables y acciones añadidas pueden necesitar restauración manual. Los cambios
ya enviados a procesos gráficos no forman parte de la transacción de archivos.

Recommended testing después del despliegue de main:

- [ ] Ambos modos/presets en barra, Rofi, Kitty, Starship y Hyprland; terminales
  nuevas y existentes; Nexus después de reiniciar.
- [ ] Wi-Fi, bloqueo, suspensión, audio, capturas y monitores en Desktop/Victus.
- [ ] Blender GUI y un render CUDA/OptiX real en NVIDIA directo y PRIME.
- [ ] Sesión prolongada y memoria de Caelestia: los límites contienen el crecimiento;
  no demuestran que la fuga upstream haya desaparecido.
- [ ] Cuando exista destino de respaldo, realizar su ensayo real de restauración
  antes de habilitar poda. Migrar Docker y LUKS sólo con datos recuperables.
