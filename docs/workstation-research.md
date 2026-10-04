# Investigación y decisiones del refactor

Consulta realizada para este cambio: 2026-10-03. Las versiones de esta tabla
son las evaluadas del lock anterior y del nuevo; no una promesa de mantener
siempre la última versión publicada. Las fuentes enlazadas son upstream.

## Proyectos similares

| Referencia | Qué aprovechamos | Qué no trasladamos |
| --- | --- | --- |
| [nix-starter-configs](https://github.com/Misterio77/nix-starter-configs) | Módulos separados NixOS/Home Manager, paquetes propios y dotfiles declarativos | Copiar una plantilla completa; su autor advierte que puede estar desactualizada |
| [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config) | Separar hosts, módulos compartidos y composición de usuario | Infraestructura, hardware o escritorios de otra persona |
| [nixos-unified](https://github.com/srid/nixos-unified) | Una interfaz coherente y outputs derivados, no listas repetidas de hosts | Un framework adicional para dos workstations Linux; reconsiderarlo al incorporar un sistema operativo distinto |
| [nixos-hardware](https://github.com/NixOS/nixos-hardware) | Reutilizar quirks documentados cuando exista coincidencia exacta de equipo | Adivinar módulos del portátil de reemplazo antes de conocer su modelo |

La conclusión es mantener el sistema de módulos nativo, imports explícitos y
el inventario existente. Escalabilidad aquí significa añadir una capacidad,
perfil o dotfile sin duplicar un Home completo, no introducir más frameworks.

## Actualizaciones aplicadas

Se actualizaron selectivamente `nixpkgs`, Home Manager, Catppuccin, treefmt-nix,
llm-agents y Herdr. El `flake.lock` conserva revisiones y hashes reproducibles.
Los paquetes propios conservan versiones y hashes del artefacto del proveedor.

| Herramienta/componente | Antes | Nuevo lock/paquete |
| --- | --- | --- |
| Firefox | 155.0 | 157.0 |
| Google Chrome | 152.0.7977.82 | 154.0.8037.92 |
| Kitty | 0.48.2 | 0.49.1 |
| PipeWire | 1.6.8 | 1.6.9 |
| systemd | 261.2 | 261.3 |
| Tailscale | 1.102.3 | 1.102.5 |
| Thunar | 4.20.9 | 4.20.10 |
| Codex | 0.159.1 | 0.160.0 |
| Claude Code | 2.1.285 | 2.1.289 |
| Herdr | 0.9.1 | 0.9.3 |
| Kiro CLI | 2.23.0 | 2.25.0 |
| Kiro IDE | 1.1.14 | 1.1.70 |
| DbGate | 7.3.0 | 7.3.1 |

Las versiones generales se verifican con `nix eval` sobre
`nixosConfigurations.desktop.pkgs`; los asistentes con `lib.aiToolVersions`.
Las revisiones de inputs se verifican con `nix flake metadata`.
[Kiro](https://kiro.dev/changelog/),
[DbGate 7.3.1](https://github.com/dbgate/dbgate/releases/tag/v7.3.1) y
[Herdr 0.9.3](https://github.com/herdrdev/herdr/releases/tag/v0.9.3) respaldan
las actualizaciones de los paquetes fuera de nixpkgs.

Hyprland 0.56.2, Nix 2.34.8, Neovim 0.12.5, mpv 0.41.0 y Syncthing 2.1.3
permanecen en las mismas versiones evaluadas. No se fuerza una actualización
por número. Tampoco se cambia `stateVersion`: controla compatibilidad de
estado, no la versión de los paquetes.

El Home Manager actualizado permite sustituir las opciones renombradas por
`programs.neovim.initLua` y `programs.rofi.settings`. La política de journal
usa `services.journald.settings.Journal`, el contrato del nixpkgs actualizado.
Firefox fija su ruta existente para no mover los perfiles al nuevo default XDG.

El build completo detectó una incompatibilidad real en SonoBus 1.7.2: su
`VersionInfo` deja de ser agregado bajo el nuevo default C++20 de
[GCC 16](https://gcc.gnu.org/gcc-16/changes.html). Se conserva la aplicación,
fuente y toolchain actuales; `packages/sonobus.nix` fija C++17 explícitamente,
el nivel usado por [su CMake upstream](https://github.com/sonosaurus/sonobus/blob/1.7.2/CMakeLists.txt).
Este override debe retirarse cuando upstream/nixpkgs incorpore una solución.

## Monitores: decisión basada en el contrato real

Se examinó [el módulo Kanshi de Home Manager](https://github.com/nix-community/home-manager/blob/acd21c5a3420a9d5fd0ed06299b10828267ef9ba/modules/services/kanshi.nix),
[Kanshi 1.9.0](https://gitlab.freedesktop.org/emersion/kanshi/-/blob/v1.9.0/main.c)
y el [gestor de reglas de Hyprland 0.56.2](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/config/shared/monitor/MonitorRuleManager.cpp).
El estado aplicado por wlr-output-management tiene prioridad sobre reglas IPC.
Una combinación Kanshi + fallback/manual por `hyprctl` conserva overrides del
primer escritor y puede impedir los cambios del segundo.

Se implementa un solo escritor por eventos IPC: reconoce make/model/serial,
verifica modos anunciados, calcula un fallback para pantallas desconocidas y
permite una pausa manual. No depende de hostnames, nombres de conectores ni
del foco. No se atribuye al Kanshi actual el bug no-op de Hyprland 0.56.0:
el [protocolo en 0.56.2](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/protocols/OutputManagement.cpp)
ya incluye la corrección. La matriz física pendiente está en [monitors.md](monitors.md).

## Recursos: cambios medibles, no ahorro supuesto

- Journal acotado a 1 GiB persistente, 128 MiB runtime y 14 días. El baseline
  observado ocupaba 3.9 GiB. Al desplegar pueden expirar logs antiguos; no se
  ejecutó vacuum durante este trabajo.
- Chrome/Neovim/fastfetch dejan de duplicar propiedad entre NixOS y Home Manager.
  Nix ya deduplica archivos en el store: esto simplifica ownership, no demuestra
  un ahorro de RAM.
- Docker permanece por socket, libvirt no arranca guests automáticamente y no
  quedan workloads K3s/CI/lab. Retirar declaraciones no equivale a borrar datos.
- La base diaria no importa Android/Flutter/Jupyter/creatividad. Los dos equipos
  actuales sí los eligen explícitamente, conservando sus flujos existentes.
- Se conservan límites de Nix, zram/swap y políticas de suspensión actuales.
  No se cambia OOM ni se promete menor consumo sin medir el equipo real.

La justificación y mediciones posteriores están en [resource-policy.md](resource-policy.md).

## Decisiones diferidas y límites

- **Caelestia:** conservar su pin y los pins de CLI/Quickshell. La
  [evolución upstream](https://github.com/caelestia-dots/shell) incluye una
  reestructuración de configuración que necesita probar los overrides locales
  de colores/Wi-Fi/locking; no se actualiza silenciosamente junto a arquitectura.
- **SDKs:** conservar compatibilidad global mientras cada proyecto migra a su
  devShell. Quitarla de golpe rompería proyectos todavía no migrados.
- **Creatividad:** conservar la excepción Blender standalone y comprobar GUI/GPU
  tras despliegue. No sustituir suites por alternativas sin una necesidad real.
- **Datos y acceso:** no migrar sesiones, credenciales, VMs o bases de datos al
  store. Retirar la ThinkPad del inventario no revoca su nodo externo Tailscale.
- **Darwin y nuevo hardware:** no exportar hosts ficticios desplegables; se
  requiere hardware real y una migración explícita de los módulos Linux.

Esta revisión utiliza los mecanismos de Nix que aportan garantías verificables:
composición tipada, lock, builds, checks positivos/negativos y separación entre
configuración declarada, resultado construido y generación activa.
