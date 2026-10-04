# NixOS Multi-Host Dev Environment

Configuración modular de NixOS + Flakes + Home Manager orientada al uso diario, desarrollo y creación audiovisual con escritorio Wayland (Hyprland), herramientas modernas de IA y soporte multi-máquina.

---

## Índice

- [Máquinas soportadas](#máquinas-soportadas)
- [Despliegue rápido](#despliegue-rápido)
- [Atajos de teclado](#atajos-de-teclado)
- [Escritorio (Caelestia Shell)](#escritorio-caelestia-shell)
- [Herramientas de IA](#herramientas-de-ia)
- [Base de datos y terminal](#base-de-datos-y-terminal)
- [Edición 3D / Video](#edición-3d--video)
- [Para qué está preparado este entorno](#para-qué-está-preparado-este-entorno)
- [Trabajar con Flakes en proyectos](#trabajar-con-flakes-en-proyectos)
- [Agregar una nueva máquina](#agregar-una-nueva-máquina)
- [Comandos de mantenimiento](#comandos-de-mantenimiento)

---

## Máquinas soportadas

| Host | Estado | Hardware |
|---|---|---|
| `victus` | Activo | HP Victus — AMD HawkPoint + NVIDIA RTX 4050 |
| `desktop` | Activo | Desktop — NVIDIA RTX 3060 Ti |

La arquitectura y el procedimiento para extender dotfiles están en
[docs/workstation-architecture.md](docs/workstation-architecture.md).
ThinkPad fue retirado del inventario; este repo no administra servidores.

---

## Despliegue rápido

### Clonar en una máquina nueva

```bash
git clone <repo> ~/nixos-config
cd ~/nixos-config
```

### Generar configuración de hardware

```bash
sudo nixos-generate-config --show-hardware-config > hosts/<nombre>/hardware-configuration.nix
```

### Primera activación

```bash
# `nix-switch` aún no existe en una instalación nueva.
sudo nixos-rebuild switch --flake ".#victus"
```

### Actualizar una máquina existente

```bash
nix-update
```

`nix-update` es el único flujo de despliegue diario: exige un árbol limpio en
`main`, obtiene `origin/main` solo mediante fast-forward, valida el flake,
activa el host detectado. No actualiza inputs de Nix ni mezcla cambios locales.

La primera vez que una máquina recibe estos comandos, actualiza el checkout de
`main` y activa la generación una vez con el flujo anterior:

```bash
git switch main
git pull --ff-only
nix-switch
```

Después de esa migración, usa únicamente `nix-update`.

`nix-switch` y `nix-home-switch` activan respectivamente el sistema completo o
solo Home Manager, pero únicamente desde un `main` limpio que coincida
exactamente con `origin/main`. En ramas de desarrollo usa `nix-format`,
`nix-check` y `nix-config build`; nunca actives la rama. Consulta
[docs/nix-config.md](docs/nix-config.md) para el catálogo completo.

### Limpiar el portapapeles

```bash
clipboard-clear
```

El comando borra los portapapeles estándar y primario de Wayland, además del
historial de `cliphist`.

---

## Atajos de teclado

La tecla modificadora principal es `Super` (tecla Windows).

### Terminal y lanzadores

| Atajo | Acción |
|---|---|
| `Super + Enter` | Abrir Kitty (terminal) |
| `Super + R` | Lanzador de apps (Caelestia) |
| `Super + D` | Dashboard de Caelestia (media, clima, info del sistema) |
| `Super + B` | Firefox |
| `Super + T` | Thunar (gestor de archivos) |

### Ventanas

| Atajo | Acción |
|---|---|
| `Super + Q` / `Super + C` | Cerrar ventana activa |
| `Super + F` | Pantalla completa |
| `Super + E` | Flotante / Tiled |
| `Super + Shift + E` | Centrar la ventana flotante activa |
| `Super + P` | Fijar / desfijar en todos los workspaces (pin) |
| `Super + G` | Agrupar ventanas |
| `Super + Tab` | Cambiar en el grupo activo |
| `Alt + Tab` / `Alt + Shift + Tab` | Ciclar entre ventanas (incluye flotantes) y traerlas al frente |
| `Super + ←↑↓→` | Mover foco entre ventanas |
| `Super + Shift + ←↑↓→` | Mover ventana físicamente |
| `Super + arrastrar (clic izq)` | Mover una ventana (útil para flotantes) |
| `Super + arrastrar (clic der)` | Redimensionar una ventana |
| `Super + S` | **Modo resize** (flechas redimensionan, Escape/Enter salen) |
| `Super + -` (minus) | Mostrar/ocultar el cajón de ventanas (scratchpad) |
| `Super + Shift + -` | Enviar la ventana activa al cajón |

> Las ventanas flotantes no tenían forma de arrastrarse/redimensionarse con el
> mouse ni de ciclarse con teclado hasta agregar estos binds — Caelestia no
> gestiona ventanas, solo aporta un popout en la barra (clic sobre el título de
> la ventana activa) con botones **Float/Tile, Pin/Unpin, Kill** y una
> cuadrícula para moverla a otro workspace, como complemento gráfico a estos
> atajos.

### Workspaces (escritorios virtuales)

| Atajo | Acción |
|---|---|
| `Super + 1…9` / `Super + 0` | Ir al workspace 1–10 |
| `Super + Shift + 1…9` / `Super + Shift + 0` | Mover ventana al workspace 1–10 |
| `Super + Ctrl + ←` / `→` | Workspace anterior / siguiente |
| `Super + scroll` | Navegar workspaces con el mouse |

### Sesión y energía

| Atajo | Acción |
|---|---|
| `Super + L` | Bloquear pantalla (Caelestia Lock) |
| `Super + Escape` | Menú de sesión (Caelestia) — apagar, reiniciar, suspender, cerrar sesión |
| `Super + M` | Salir de Hyprland sin menú (emergencia) |

### Notificaciones

| Atajo | Acción |
|---|---|
| `Super + N` | Abrir/cerrar sidebar de notificaciones + quick toggles (Caelestia) |
| `Super + Alt + N` | Limpiar todas las notificaciones |

### Productividad

| Atajo | Acción |
|---|---|
| `Super + V` | Historial del portapapeles (cliphist → Rofi) |
| `Super + Shift + S` | Captura de área → portapapeles |
| `Print` | Captura completa → `~/Pictures/Screenshots/` |
| `Super + Shift + P` | Selector de color (hyprpicker) |
| `Super + Shift + C` | Selector de color nativo de Caelestia (alternativa a hyprpicker) |
| `Super + Shift + Alt + S` | Captura con freeze + anotación (swappy) |
| `Super + Shift + K` | Cheatsheet de todos los atajos activos (Rofi) |

### Pantalla y multimedia

| Atajo | Acción |
|---|---|
| `Super + Shift + W` | Alternar luz cálida / filtro de luz azul (`wlsunset`) — equivalente gráfico de `night-auto` / `night-off` |
| `XF86MonBrightnessUp` / `Down` | Brillo de pantalla, con OSD visual de Caelestia |
| `XF86AudioPlay` / `Next` / `Prev` / `Stop` | Control de medios (reproductor activo), vía Caelestia |

### Teclado

| Atajo | Acción |
|---|---|
| `Shift izq + Shift der` | Alternar entre teclado inglés (us) y español latinoamericano |

> El LED de Scroll Lock indica qué layout está activo.

### Barra lateral (Caelestia)

La barra ya no es Waybar: es la barra vertical/sidebar de Caelestia Shell,
con el contenedor `statusIcons` mostrando batería/rendimiento, red y
bluetooth en un solo lugar. El perfil de energía (balanceado / máximo
rendimiento / ahorro) se cicla desde ese mismo icono, igual que antes.

### Luz nocturna (terminal)

```bash
night-soft   # 4200K suave
night-warm   # 3200K cálido
night-off    # desactivar
night-auto   # restaurar el servicio automático (wlsunset)
```

> `Super + Shift + W` hace lo mismo que `night-off` / `night-auto`, pero
> como atajo gráfico (con notificación) en vez de comandos de terminal.

---

## Escritorio (Caelestia Shell)

El escritorio corre sobre [Caelestia Shell](https://github.com/caelestia-dots/shell)
(quickshell / Qt6), que reemplaza Waybar + SwayNC + wlogout, y una parte de
Rofi/hyprpicker (barra, launcher, dashboard, notificaciones, selector de
color, menú de sesión). Se integra vía el módulo oficial de home-manager del
proyecto (`inputs.caelestia-shell`, ver `modules/home/caelestia.nix`).

### Cambiar de esquema de color

```bash
caelestia scheme list --names                          # ver esquemas disponibles
caelestia scheme set --name dracula --mode dark
caelestia scheme set --name catppuccin --flavour mocha  # esquema por defecto
```

Kitty, Rofi, Starship y los bordes de Hyprland heredan el esquema activo.
Caelestia renderiza sus plantillas en el directorio de estado del usuario;
Kitty y Hyprland se recargan en caliente. Catppuccin Mocha y Latte usan sus
colores originales con acento lavender y contraste legible.

### Perfiles de personalización

```bash
desktop-preset list
desktop-preset apply diario   # Mocha, transparencias moderadas
desktop-preset apply claro    # Latte, superficies opacas
desktop-preset apply enfoque  # Mocha, sin animaciones ni transparencias
desktop-preset status
```

También aparecen como acciones del launcher: abre `Super+R` y escribe `>`.
Incluyen luz cálida, No molestar, captura congelada, QPWGraph, monitores y
`workstation-doctor`. Los perfiles conservan tus fuentes, favoritos y ajustes
ajenos a su apariencia. Consulta [docs/personalization.md](docs/personalization.md)
para los valores concretos, la recuperación ante errores y las pruebas en sesión.

### Modo claro / oscuro

El tema oscuro por defecto es Catppuccin **Mocha**; el claro es Catppuccin
**Latte**. El cambio es global (barra/shell, kitty, GTK, Qt, btop, fuzzel,
colores de Hyprland). El wallpaper es independiente del modo y no cambia con
el toggle — ver sección "Wallpapers" más abajo. Tres formas equivalentes de
dispararlo:

```bash
theme-light    # fuerza modo claro (Latte)
theme-dark     # fuerza modo oscuro (Mocha)
theme-toggle   # alterna según el modo actual
```

- **Atajo**: `Super+Shift+T`.
- **Panel de Caelestia**: la sección de estilo/wallpaper del panel también
  trae un switch claro/oscuro — funciona igual que los comandos de arriba.

Todos pasan por `caelestia scheme set -m <light|dark>`. El módulo
`caelestia-scheme.nix` adapta el flavour Catppuccin correcto y reemplaza tanto
la CLI general como la CLI interna de Caelestia Shell. Los detalles de
mantenimiento están en [docs/maintainer.md](docs/maintainer.md).

### Red y configuración de Nexus

Caelestia usa NetworkManager mediante `nmcli`. El paquete lleva un parche local
en `modules/home/caelestia-scheme.nix` que comparte un único flujo entre Nexus y
el popout de la barra: solicita la contraseña antes de cambiar de red, activa
perfiles guardados por UUID, no fija BSSID y no borra perfiles cuando un intento
falla. Esto permite roaming entre puntos de acceso que publican el mismo SSID.

`~/.config/caelestia/shell.json` es intencionalmente mutable. Home Manager
instala valores iniciales y completa únicamente las opciones ausentes; los cambios
hechos desde Nexus persisten entre reinicios y actualizaciones. Las plantillas,
wrappers y políticas que sí forman parte del sistema continúan declaradas en
Nix.

Caelestia Lock es el único locker de la sesión. Hypridle conserva los tiempos de
atenuación, DPMS y suspensión, pero tanto `Super+L` como el bloqueo automático
delegan en Caelestia para evitar dos clientes `ext-session-lock` concurrentes.

### Monitores externos

La distribución se activa por las pantallas conectadas, no por el hostname.
Tres monitores del escritorio conocido conservan el LG central y los laterales
a 90°/270°, con refrescos 99.95/165 Hz. Dos externos conocidos tienen su perfil;
un portátil con dos pantallas desconocidas recibe un layout horizontal seguro.
Las identidades EDID están en `inventory/displays.nix`, sin conectores fijos.

```bash
monitor-auto status
monitor-layout --dry-run          # muestra el perfil sin aplicarlo
set-monitor left portrait DP-3 HDMI-A-1  # pausa automatismo y ajusta manualmente
monitor-auto on                  # vuelve a los perfiles automáticos
```

Con tres o más monitores, `set-monitor` requiere OUTPUT y ANCHOR explícitos.
El controlador escucha eventos de Hyprland, no hace polling, y acompaña la
sesión gráfica. Consulta [docs/monitors.md](docs/monitors.md) para la selección,
las pruebas físicas pendientes y las limitaciones.

### Wallpapers

El fondo de pantalla se gestiona de forma nativa por Caelestia
(`background.wallpaperEnabled = true`, `modules/home/caelestia.nix`): es un
solo wallpaper estático, compartido por todos los monitores (Caelestia no
soporta un wallpaper distinto por pantalla, ni animación — solo
jpg/jpeg/png/webp/svg/tiff, nada de gifs).

Para elegirlo, sin tocar la terminal:
- **Panel** (Super+D, dashboard) o la página de estilo/wallpaper del panel:
  botones "Browse" (abre selector de archivos) y "Random" (elige uno al azar
  de `paths.wallpaperDir`).
- **Launcher** (Super+R): busca el wallpaper por nombre, igual que una app.

`~/Pictures/Wallpapers/Fleet-Catppuccin/` incluye tres fondos de
[`yukazakiri/themed-wallpapers`](https://github.com/yukazakiri/themed-wallpapers),
fijados por revisión y hash en `packages/catppuccin-wallpapers.nix`. Se obtienen
durante el build, sin clonar repositorios al iniciar la sesión. Tus imágenes y
las colecciones anteriores se conservan; cualquier imagen que agregues bajo
`~/Pictures/Wallpapers/` aparece también en el selector.

Si prefieres terminal de todos modos: `caelestia wallpaper -f <ruta>` fija una
imagen puntual, `caelestia wallpaper -r` elige una al azar.

### Plugins de Caelestia

La carpeta `plugin/` del proyecto es un módulo nativo Qt6/C++ que el propio
shell compila para registrar sus tipos internos de QML (config, efectos de
blur, detección de beat del visualizador) — **no es un sistema de
extensiones para el usuario**. No hay marketplace ni carpeta "drop-in"; para
agregar algo ahí habría que parchar el QML del shell directamente.

---

## Herramientas de IA

Claude Code, Codex, OpenCode y RTK se instalan desde el input `llm-agents`.
Kiro CLI e IDE conservan sus paquetes propios. La configuración, los proveedores
y las credenciales de OpenCode pertenecen al usuario; este repositorio instala
solo su binario, sin wrappers, agentes, skills, plugins ni gateway personalizados.

Consulta [docs/maintainer.md](docs/maintainer.md) para actualizar las versiones.

---

## Base de datos y terminal

Los perfiles de desarrollo incluyen clientes para bases de datos, sin iniciar
un servidor en cada workstation:

| Herramienta | Host | Uso |
|---|---|---|
| DbGate Community | Ambos | Cliente gráfico para SQL, MongoDB y Redis |
| DBeaver | Opcional con `nix run .#dbeaver` | Cliente gráfico para SQL y motores con drivers JDBC |
| MySQL Workbench | Ambos | Administración y modelado de MySQL/MariaDB |
| `usql` | Todos | Cliente de terminal para PostgreSQL, MySQL/MariaDB, SQLite, SQL Server, Oracle y otros |

Ejemplos de `usql`:

```bash
usql postgres://usuario@host/base
usql mysql://usuario@host/base
usql sqlite3://$PWD/dev.db
```

`usql` guarda conexiones nombradas en `~/.config/usql/config.yaml`; ese archivo
puede contener secretos y no se versiona. No se declara un servidor MariaDB local.

La terminal incluye `zoxide` (`z <directorio>`), `lazygit`, `delta`, `yazi`,
completion visual con `fzf-tab` y búsqueda de historial por texto con las
flechas arriba/abajo. `Ctrl-R` usa FZF. El binario de Atuin permanece disponible
para uso manual, pero su integración Zsh está desactivada para no instalar
hooks SQLite redundantes en cada terminal. Zsh deduplica las funciones estándar
de `fpath` antes de ejecutar `compinit` una sola vez.


---

## Edición 3D / Video

Stack de creación audiovisual para los hosts NVIDIA: `victus` usa su RTX 4050
mediante PRIME offload y `desktop` usa su RTX 3060 Ti como GPU principal.

| Adobe | Aquí | Instalado vía |
|---|---|---|
| Premiere + Color | **DaVinci Resolve** (gratis) | `modules/home/creative-suite.nix` (`davinci-resolve`) |
| After Effects (compositing) | **Fusion** (dentro de Resolve) | — |
| Cinema4D / 3D | **Blender** (CUDA/OptiX reales) | `modules/home/blender-gpu.nix` (standalone) |
| NLE ligero / respaldo | **Kdenlive** | `modules/home/creative-suite.nix` (`kdePackages.kdenlive`) |
| Photoshop | **Krita** + **GIMP 3** | `modules/home/creative-suite.nix` (`krita`, `gimp`) |
| Illustrator | **Inkscape** | `modules/home/creative-suite.nix` (`inkscape`) |

La selección común de `homeProfiles` incluye `creative` en ambos equipos.
El perfil requiere capacidad NVIDIA; la base diaria no depende de ese hardware.

**Blender:** el archivo oficial de blender.org **5.2.1**, con los backends
GPU de Cycles, está empaquetado en `packages/blender-standalone.nix` con versión
y SHA-256 fijos. Nix resuelve sus bibliotecas y lo construye antes de actualizar
el equipo. El paquete de nixpkgs sigue disponible como alternativa CPU; las
instalaciones antiguas en `~/.local/opt/blender` se conservan sin usarse.

### Lanzadores

```bash
resolve       # DaVinci Resolve, GPU dedicada y XWayland
blender-gpu   # Blender oficial mediante gpu-launch
blender       # Blender oficial, con selección normal de GPU
blender-cpu   # Blender de nixpkgs
```

Son ejecutables declarados, disponibles para la sesión gráfica y las terminales.
Los lanzadores de escritorio llaman a los mismos wrappers; tras actualizar
desde main revisado, vuelve a iniciar la sesión para renovar su entorno.
`kdenlive`, `krita`, `gimp` e `inkscape` se lanzan directamente.

El paquete oficial usa SDL3 de Nix y expone `/run/opengl-driver/lib` al loader.
Las bibliotecas CUDA/OptiX y los controladores opcionales de Intel/AMD dependen
del hardware activo. La prueba automática abre Blender en segundo plano y
comprueba Cycles; la interfaz, los dispositivos CUDA/OptiX y un render real
deben comprobarse en Desktop y Victus después del despliegue de main.

### Flujo de trabajo con Resolve (versión gratis)

**Importante:** la versión gratis de DaVinci Resolve en Linux **no
importa/exporta H.264/H.265** (limitación de licencia, no del hardware) — el
metraje típico de cámara/celular necesita transcodificarse antes:

```bash
# 1. Ingesta: H.264/H.265 -> DNxHR HQ (editable sin problemas en Resolve gratis)
to-dnxhr clip1.mp4 clip2.mp4

# 2. Edita/corrige color/compón en Resolve, exporta un master DNxHR/ProRes.

# 3. Entrega: master -> H.264 vía NVENC (rápido, en GPU)
to-h264 master.mov
```

Si el paso extra molesta a futuro, la salida es comprar **Resolve Studio**
(~$295 pago único, sí trae esos códecs) — cambiar `davinci-resolve` por
`davinci-resolve-studio` en `modules/home/creative-suite.nix`.

### Notas

- **Techo real de "alta calidad":** 6 GB de VRAM alcanzan sobrado para 1080p
  y 4K moderado; vigilar en escenas Blender muy pesadas o grados 4K con
  muchos nodos.
- **Primera vez con Resolve:** crea su base de datos de proyectos en disco al
  primer arranque (puede tardar un poco); si la GUI no abre bajo Hyprland, el
  lanzador ya fuerza XWayland, que es la causa más común de fallos con apps
  Qt en compositores Wayland nuevos.
- **Respaldo si Resolve da problemas:** Kdenlive ingesta H.264 directo con
  NVENC, sin necesidad de transcodificar — cubre el rol de NLE mientras se
  resuelve cualquier fricción con Resolve.
- **natron** (compositor nodal FOSS, alternativo a Fusion) se evaluó pero
  está marcado `broken` en el pin actual de nixpkgs-unstable — omitido por
  ahora; Fusion (dentro de Resolve) cubre ese rol.
- **Actualizar Blender standalone:** cambia la versión y el hash en
  `packages/blender-standalone.nix`, construye ambos sistemas y hogares, y
  revísalo mediante PR. No hace falta borrar instalaciones ni datos locales.

---

## Recuperación y seguridad pendiente

Los respaldos Restic están preparados y **desactivados** hasta definir destino
y carpetas. Docker conserva su configuración actual; la opción sin privilegios
requiere una migración revisada de datos y GPU. El cifrado de discos también
requiere un procedimiento de recuperación antes de migrar. La ThinkPad sigue
retirada de la flota y sus datos se conservan. Consulta
[docs/recovery.md](docs/recovery.md) para estos procedimientos.

---

## Para qué está preparado este entorno

### Stacks de desarrollo incluidos

| Stack | Herramientas |
|---|---|
| **Mobile / Flutter** | Flutter, Dart (vía Flutter), Android Studio, Android Tools, FVM (versiones de Flutter), Kotlin |
| **Web / Node** | Node.js 22, npm, pnpm (vía corepack), Go, Python 3 |
| **Backend** | Go, .NET 8 SDK, gRPC (grpcurl), httpie, Bruno, Postman, Insomnia |
| **C / C++** | GCC, Make, CMake, GDB |
| **Data / Python** | Python 3, pip, Micromamba |
| **DevOps** | Docker + Compose, GitHub CLI (`gh`) |
| **IA / Agentes** | Claude Code, Codex (OpenAI CLI), Kiro IDE (`victus` y `desktop`), Kiro CLI, OpenCode, Herdr |
| **3D / Video** | DaVinci Resolve, Blender, Kdenlive, Krita, GIMP, Inkscape, ffmpeg (ver [Edición 3D / Video](#edición-3d--video)) |

### Herramientas de terminal

| Herramienta | Uso |
|---|---|
| `bat` | `cat` con syntax highlight |
| `eza` | `ls` con iconos (`ll`, `la`, `lla`, `tree`) |
| `fzf` | Búsqueda fuzzy interactiva |
| `btop` | Monitor de sistema |
| `fastfetch` (`ff`) | Info del sistema |
| `ripgrep` | Búsqueda en código (más rápida que grep) |
| `jq` | Procesar JSON |
| `7z`, `zip`, `zstd`, `rar` | Compresión/descompresión de múltiples formatos |

### Comandos y aliases útiles

```bash
ls / ll / la / lla / tree   # eza con iconos
v                            # neovim
c                            # clear
ff                           # fastfetch
nix-switch                   # reconstruir sistema
nix-home-switch              # reconstruir solo perfil de usuario
nix-update                   # actualizar main y desplegar el host actual
nix-check                    # validar y construir el host actual
nix-check all                # validar y construir todos los hosts
nix-clean                    # borrar generaciones con más de 30 días
pritunl                      # abre la GUI de Pritunl VPN
```

### VPN Pritunl

El cliente Pritunl (`pritunl-client`) se instala a nivel de **sistema**
(`modules/system/pritunl.nix`, importado desde
`modules/system/workstation.nix`, así que está disponible en las estaciones
de trabajo del repo) — no hace falta descargar nada a mano ni AppImages: nixpkgs ya trae el
paquete completo (CLI + daemon privilegiado + GUI Electron), compilado desde
fuente. El daemon (`pritunl-client.service`) arranca solo con el sistema.

```bash
pritunl                      # alias a la GUI (pritunl-client-electron)
pritunl-client --help        # CLI real
pritunl-client add <perfil.ovpn | uri-pritunl://...>
pritunl-client list
pritunl-client start <profile-id>
```

### Claude Code

Claude Code conserva la experiencia oficial de primer inicio y administra su
propia configuración local en `~/.claude`:

```bash
claude              # elegir autenticación en el primer inicio
claude doctor       # diagnóstico
```

---

## Trabajar con Flakes en proyectos

### ¿Por qué usar Flakes por proyecto?

`direnv` + `nix-direnv` están habilitados globalmente. Cada proyecto puede tener
su propio entorno de herramientas aislado: al entrar a la carpeta, las herramientas
aparecen; al salir, desaparecen. Sin contaminar el sistema global.

### Setup en un proyecto existente

```bash
cd ~/mi-proyecto

# 1. Crear el flake del proyecto
cat > flake.nix << 'EOF'
{
  description = "Dev shell del proyecto";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
      in {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            # Agrega aquí las herramientas específicas del proyecto
            nodejs_22
            go
            # python3
            # flutter
          ];
          shellHook = ''
            echo "Entorno listo"
          '';
        };
      });
}
EOF

# 2. Activar direnv
echo "use flake" > .envrc
direnv allow
```

A partir de ahí, cada vez que entres a la carpeta el entorno se activa solo.

### Plantillas por stack

**Go + gRPC:**
```nix
packages = with pkgs; [ go protobuf grpc-tools mockgen gotestsum ];
```

**Flutter / Android:**
```nix
packages = with pkgs; [ flutter android-tools ];
shellHook = ''
  export ANDROID_HOME="$HOME/Android/Sdk"
  export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH"
'';
```

**Node / TypeScript:**
```nix
packages = with pkgs; [ nodejs_22 ];
shellHook = "corepack enable";
```

**Python:**
```nix
packages = with pkgs; [ python3 python3Packages.pip python3Packages.virtualenv ];
shellHook = ''
  [ -d .venv ] || python -m venv .venv
  source .venv/bin/activate
'';
```

### Comandos útiles de Flakes

```bash
nix flake show          # ver outputs del flake actual
nix flake update        # primitiva; en este repo prefiere nix-input-update
nix flake metadata      # info de entradas y revisiones
nix develop             # entrar al devShell manualmente (sin direnv)
nix build               # construir el output por defecto
```

### Actualizar las dependencias del sistema

Esto se hace en un branch y PR dedicado, nunca con `nix-update` en una
máquina de uso diario:

```bash
cd ~/nixos-config
nix-input-update        # actualiza flake.lock y valida todos los hosts
# revisa los cambios y abre un PR hacia main
```

---

## Agregar una nueva máquina

1. Crear `hosts/<nombre>/default.nix`:

```nix
{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/system
  ];

  networking.hostName = "<nombre>";

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;

  hardware.graphics.enable = true;

  system.stateVersion = "24.11";
}
```

2. Generar el hardware file:

```bash
sudo nixos-generate-config --show-hardware-config > hosts/<nombre>/hardware-configuration.nix
```

3. Agrega el host y su `hosts/<nombre>/home.nix` al registro explícito de
   workstations en `flake.nix`.

4. Desplegar:

```bash
sudo nixos-rebuild switch --flake .#<nombre>
```

---

## Comandos de mantenimiento

```bash
# Liberar generaciones con más de 30 días y optimizar el store
nix-clean

# Ver cuánto ocupa el store de Nix
du -sh /nix/store

# Actualizar firmware (BIOS, controladores)
fwupdmgr refresh
fwupdmgr update

# Ver estado del audio
wpctl status

# Ver estado del zram swap
zramctl

# Actualizaciones de firmware del sistema
fwupdmgr get-updates

# SSH a victus desde otra máquina (solo vía Tailscale, solo por llave)
ssh anthony@<ip-tailscale-de-victus>
```
