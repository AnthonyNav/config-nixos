# Arquitectura de workstations

Desktop y Victus consumen un único entorno diario. No se convierte el hardware
en una máquina ficticia: cada instalación mantiene sus discos, bootloader,
drivers, buses PCI y política de suspensión. El instalador es un output aparte.

## Capas y propiedad

```text
inventory/hosts.nix                 política común + capacidades de cada equipo
flake/hosts.nix                     composición y matriz derivados del inventario
├── hosts/<equipo>/                 hardware, discos, boot, PRIME/suspensión
├── modules/system/                 servicios/drivers compartidos de NixOS
└── home.nix → profiles/home/        entorno diario + perfiles funcionales
    ├── modules/home/<programa>.nix  paquete, opciones, integración y servicios user
    └── dotfiles/<programa>/         configuración estática portátil
```

- NixOS: red/VPN, audio, drivers, Docker y virtualización local.
- Home Manager: navegadores, terminal/editor, medios, identidades, dotfiles,
  escritorio, asistentes y perfiles opcionales.
- Proyecto: SDKs/versiones y bibliotecas específicas, con su propio lock,
  `nix develop` y direnv.
- Estado local: credenciales, sesiones, fingerprints, conexiones de bases de
  datos y archivos que Caelestia renderiza. Nunca se guardan en Git/store.

Los imports son explícitos. No hay descubrimiento automático de directorios,
framework nuevo de flakes, ramas permanentes por tema ni condicionales por
hostname dentro de la personalización.

## Entorno diario y perfiles

`profiles/home/default.nix` compone siempre la base diaria, identidades/acceso,
asistentes y controles de energía. El inventario selecciona `homeProfiles`:

| Perfil | Contenido |
| --- | --- |
| `development` | IDEs, Flutter/Android, web/backend, clientes API/database |
| `data-science` | Micromamba, DuckDB, JupyterLab y compatibilidad nativa existente |
| `creative` | Herramientas audiovisuales y lanzadores GPU, requiere NVIDIA |
| `platform` | Infraestructura/Kubernetes, seguridad, secretos y diagnósticos CLI |

Desktop y Victus seleccionan los cuatro. La base diaria funciona sin ellos:
el check `fleet-policy` evalúa una workstation sintética integrada sin
NVIDIA, VM, GPU compute ni SDKs. No exporta una máquina desplegable.

`fleet.home.profiles` es un hecho evaluado de sólo lectura, no un segundo
selector. Cambia `homeProfiles` en el inventario. `homeModules = [ ];`
permite excepciones explícitas, no copias del entorno completo.

El perfil `platform` instala clientes sin iniciar infraestructura o capturas.
Las identidades se resuelven por invocación con contexto neutral predeterminado;
Syncthing administra dos raíces y solo comparte `shared/`. Consulta
[workspace-workflow.md](workspace-workflow.md) para migración y validación.

## Agregar un dotfile

1. Busca primero el módulo nativo de Home Manager y el dueño actual del archivo.
2. Declara el paquete/opciones en `modules/home/<programa>.nix`.
3. Si la configuración es extensa y estática, usa `dotfiles/<programa>/`.
   Starship usa TOML leído por su módulo; Neovim usa Lua sin instalar SDKs/LSPs
   globales. `xdg.configFile.<ruta>.source` sirve para archivos no cubiertos
   por un módulo nativo.
4. Importa el módulo en la base, estilo o perfil funcional correspondiente.
5. Añade una prueba del contrato que modifica y construye los outputs afectados.

No enlaces credenciales o archivos mutables a `/nix/store`. Conserva los
colores generados de Kitty, CSS de GTK y `caelestia/shell.json` como estado
mutable; Home Manager administra sus fuentes/integración, no sus resultados.

## Agregar o reemplazar equipo

Genera su hardware real bajo `hosts/<nombre>/`, registra su módulo/plataforma y
selecciona capacidades. Reutiliza la política común: no copies un Home completo.
No inventes direcciones PCI, GPU o discos del equipo de reemplazo.

El constructor rechaza otros tipos de host. Todas las workstations tienen
NixOS y Home Manager. Las listas de SSH, Syncthing, input sharing y CI salen
del inventario. La matriz actual es Desktop/Victus, cuatro builds.

Esta composición sigue siendo Linux/x86_64. Darwin requiere separar módulos
Linux y paquetes no disponibles antes de agregar un Mac real; no se afirma
portabilidad entre sistemas operativos sólo por separar archivos.

## Retiro y preservación

ThinkPad deja de ser output/peer administrado. Se eliminan perfiles headless,
K3s, agentes CI, publicación web y el laboratorio AlmaLinux. Docker de desarrollo
y virt-manager/libvirt locales permanecen; no se crean VMs ni se arrancan guests.

Eliminar declaraciones no borra proyectos, claves, discos de VM, volúmenes o
estado de aplicaciones. No se ejecutan uninstall/prune ni cambios de tailnet.
Al desplegar desde main, el reconciliador de Syncthing retira el peer ThinkPad
administrado y actualiza los dispositivos de sus carpetas; no elimina archivos
ni pares ajenos a la flota. Los guests antiguos del laboratorio conservan sus
discos, pero ya no reciben su bridge/firewall específico: revisa sus redes antes
de un despliegue. Tampoco se revocan nodos Tailscale ni configuraciones Serve
persistidas fuera de estas declaraciones.
La baja del equipo laboral requiere un proceso separado y autorizado: respaldar
datos personales, cerrar sesiones y retirar identidades/pares en los servicios
externos. Este PR no realiza ni autoriza un borrado del dispositivo.

## Validación y despliegue

En rama: `nix fmt`, `nix flake check --no-build --no-write-lock-file`, checks
con build y los cuatro outputs. Publicación requiere autorización; activación
sólo desde main revisado/publicado con `nix-update`.

Builds no prueban GUI, audio, GPU, VPN, reconexión, suspensión ni autenticación.
Consulta [monitores](monitors.md), [recursos](resource-policy.md) e
[investigación](workstation-research.md). La auditoría registra evidencia y
[pruebas pendientes](workstation-audit.md), sin confundir configuración declarada
con generación activa.
