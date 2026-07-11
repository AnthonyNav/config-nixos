# NixOS Multi-Host Dev Environment

Configuración modular de NixOS + Flakes + Home Manager orientada a desarrollo diario con escritorio Wayland (Hyprland), herramientas modernas de IA y soporte multi-máquina.

---

## Índice

- [Máquinas soportadas](#máquinas-soportadas)
- [Despliegue rápido](#despliegue-rápido)
- [Atajos de teclado](#atajos-de-teclado)
- [Escritorio (Caelestia Shell)](#escritorio-caelestia-shell)
- [Kiro Gateway + opencode](#kiro-gateway--opencode)
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
| `thinkpad` | Listo (falta hardware-configuration.nix) | ThinkPad |
| `desktop` | Listo (falta hardware-configuration.nix) | Desktop |

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

### Reconstruir el sistema

```bash
# Detecta el hostname automáticamente (requiere que coincida con la carpeta del host)
nix-switch

# O explícitamente
sudo nixos-rebuild switch --flake .#victus

# Con archivos nuevos aún sin git add
sudo nixos-rebuild switch --flake "path:$PWD#victus"
```

### Solo perfil de usuario (sin cambios de sistema)

```bash
hm-switch
```

> `nix-switch` y `hm-switch` son funciones Zsh definidas en `modules/home/zsh.nix`.  
> Usan siempre `path:` internamente para soportar archivos sin rastrear por git.

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
| `Super + L` | Bloquear pantalla (hyprlock) |
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

Kitty hereda el esquema activo automáticamente: no tiene una paleta fija
propia, sino que Caelestia renderiza sus colores en caliente cada vez que
corres `caelestia scheme set` (o eliges "Scheme"/"Variant" desde el
launcher). El motor vive en `modules/home/theme-sync.nix` (plantilla tipo
pywal + `postHook` que recarga kitty vía socket de control remoto). Nota:
hyprlock, Rofi y Starship siguen fijos en Catppuccin Mocha real —
sincronizarlos requeriría más trabajo y queda pendiente como mejora futura.

### Modo claro / oscuro

El tema oscuro por defecto es Catppuccin **Mocha**; el claro es Catppuccin
**Latte**. El cambio es global (barra/shell, kitty, GTK, Qt, btop, fuzzel,
colores de Hyprland) y además cambia el fondo de pantalla automáticamente.
Tres formas equivalentes de dispararlo:

```bash
theme-light    # fuerza modo claro (Latte)
theme-dark     # fuerza modo oscuro (Mocha)
theme-toggle   # alterna según el modo actual
```

- **Atajo**: `Super+Shift+T`.
- **Panel de Caelestia**: la sección de estilo/wallpaper del panel también
  trae un switch claro/oscuro — funciona igual que los comandos de arriba.

Todos pasan por `caelestia scheme set -m <light|dark>`. Internamente esto
necesitó dos fixes (detalle completo en `CLAUDE.md`):

1. Catppuccin en caelestia-cli tiene **mocha solo con modo dark** y **latte
   solo con modo light** (son flavours distintos, no una sola paleta con
   ambos modos), así que un `-m light` "a secas" contra el flavour mocha
   revienta. `modules/home/caelestia-scheme.nix` intercepta esa llamada
   concreta (la misma que usa el switch del panel) y le agrega
   `--name catppuccin --flavour latte/mocha` según el modo pedido; cualquier
   otro uso de `caelestia scheme set` (con `--flavour`/`--name` explícitos,
   como el bootstrap de `theme-sync.nix`) pasa intacto.
2. El binario `caelestia-shell` trae su **propia** copia de la CLI empacada
   en su PATH interno (vía `makeWrapper --prefix PATH`, así lo compila
   upstream), separada del `caelestia` que se instala en el perfil general.
   Esa copia interna ganaba siempre sobre nuestro wrapper del punto 1 — por
   eso los comandos de terminal y el atajo ya funcionaban, pero el switch del
   panel (que corre dentro del proceso del shell) no. El mismo archivo
   reconstruye la variante "with-cli" de `caelestia-shell` pasándole nuestra
   CLI ya envuelta en ese mismo argumento, así el switch del panel también
   resuelve al wrapper.

El cambio de fondo lo hace `set-wallpaper` (`modules/home/theme-mode.nix`),
llamado tanto al iniciar sesión (`exec-once` en `hyprland.nix`, respeta el
modo persistido en `~/.local/state/caelestia/scheme.json`) como desde el
`postHook` de Caelestia en caliente cada vez que cambias de modo
(`modules/home/caelestia.nix`): oscuro usa `fondo.gif`, claro usa
`fondo-light.gif` (un gif de nubes de Wikimedia Commons, fijado por
SHA-256 — ver `modules/home/wallpapers.nix`; es un placeholder genérico, no
combina temáticamente con `fondo.gif`. Para poner el tuyo, deja tu propio
archivo en `~/Pictures/Wallpapers/fondo-light.gif`: nunca se sobreescribe si
ya existe, igual que `fondo.gif`).

### Wallpapers

`~/Pictures/Wallpapers/` contiene `fondo.gif` (el fondo animado actual, vía
`mpvpaper`) más subcarpetas por tema (`catppuccin/`, `nord/`, `dracula/`,
`gruvbox/`, `tokyo-dark/moon/storm/`, `solarized/`, `onedark/`) que combinan
con los esquemas de color de arriba. Se descargan solas la primera vez desde
[`yukazakiri/themed-wallpapers`](https://github.com/yukazakiri/themed-wallpapers)
(ver `modules/home/wallpapers.nix`) sin tocar `fondo.gif`. El selector de
wallpapers del launcher de Caelestia las lista directamente.

### Plugins de Caelestia

La carpeta `plugin/` del proyecto es un módulo nativo Qt6/C++ que el propio
shell compila para registrar sus tipos internos de QML (config, efectos de
blur, detección de beat del visualizador) — **no es un sistema de
extensiones para el usuario**. No hay marketplace ni carpeta "drop-in"; para
agregar algo ahí habría que parchar el QML del shell directamente.

---

## Kiro Gateway + opencode

[`kiro-gateway`](https://github.com/Jwadow/kiro-gateway) es un proxy de
comunidad que expone los modelos de Kiro (Claude Opus/Sonnet/Haiku 4.5+,
DeepSeek, Qwen, GLM, MiniMax...) como una API OpenAI/Anthropic-compatible, para
poder usarlos desde **opencode** (ya instalado, ver `home.nix`) u otras
herramientas que acepten `baseURL` + `apiKey`.

**Diseño a propósito desacoplado de Nix** (es una herramienta de comunidad,
puede ser temporal): el código, el venv de Python y los secretos viven fuera
del store, en `~/dev/shared/kiro-gateway/`. Nix solo aporta un
`systemd --user service` mínimo (`modules/home/kiro-gateway.nix`) que lo
arranca solo al iniciar sesión. Ver ese archivo y la sección correspondiente
de `CLAUDE.md` para el detalle de la frontera Nix / fuera-de-Nix.

### Bootstrap (una sola vez, o para reproducir en otra máquina)

```bash
git clone https://github.com/Jwadow/kiro-gateway.git ~/dev/shared/kiro-gateway
cd ~/dev/shared/kiro-gateway
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

Crea `~/dev/shared/kiro-gateway/.env` (`chmod 600`, nunca se versiona):

```bash
PROXY_API_KEY="$(python3 -c 'import secrets; print(secrets.token_hex(24))')"  # invéntala, es tuya
KIRO_CREDS_FILE="/home/<usuario>/.aws/sso/cache/kiro-auth-token.json"          # token de Kiro IDE ya logueado
SERVER_HOST="127.0.0.1"
SERVER_PORT="8000"
```

`KIRO_CREDS_FILE` apunta al token que genera **Kiro IDE** al hacer login
(no requiere `kiro-cli login` aparte); el gateway lo refresca solo con el
`refreshToken` que ya trae ese archivo. Si prefieres usar `kiro-cli` en su
lugar, revisa `.env.example` del repo (Opción 3, vía su SQLite).

Aplica el `hm-switch` normal para que el `systemd.user.service` levante el
gateway automáticamente (con `ConditionPathExists`: si el venv de arriba no
existe, el servicio no falla, simplemente no corre).

### Uso diario

```bash
kgw-status   # ver si está corriendo
kgw-logs     # seguir logs en vivo
kgw-restart  # reiniciar (p.ej. tras cambiar .env)
kgw-up / kgw-down   # arrancar / parar a mano
```

```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/v1/models -H "Authorization: Bearer <tu PROXY_API_KEY>"
```

**Importante:** `/health` y `/v1/models` (arriba) **no prueban una conexión
real** — `/v1/models` devuelve una lista estática, así que pueden verse bien
aunque el chat en sí falle. La prueba real es un mensaje de verdad:

```bash
opencode run "responde solo con la palabra: funciona" -m kiro/claude-haiku-4.5
```

Si eso falla (502 / "profileArn is required" / etc.), revisa
`kgw-logs` y la sección "kiro-gateway" de `CLAUDE.md` (Troubleshooting) — ahí
está documentado el fix real que se necesitó en esta cuenta
(`KIRO_API_REGION` + `PROFILE_ARN` en el `.env`, ya aplicado en esta
máquina).

### Actualizar opencode

opencode viene de dos fuentes a la vez:

- **`~/.opencode/bin/opencode`**: instalación standalone/autoactualizable
  (`opencode upgrade`). **Es la que gana** en el PATH (`modules/home/zsh.nix`
  la antepone a todo lo demás) — así se resuelve el aviso de "hay
  actualizaciones pero no se pueden instalar": el binario de Nix vive en el
  store, de solo lectura, y `opencode upgrade` nunca puede escribir ahí.
- **El paquete de Nix** (`home.nix`, `home.packages`): solo queda como
  respaldo reproducible, igual que `claude-code`.

Bootstrap (una sola vez, o si `~/.opencode` se borra):
```bash
curl -fsSL https://opencode.ai/install | bash
# o, con el opencode de Nix como bootstrapper de un solo uso:
opencode upgrade --method curl
```
Después de eso, `opencode upgrade` funciona normal, para siempre.

### Config de opencode

`~/.config/opencode/config.json` (fuera de Nix, editable a mano — agregar un
modelo no requiere rebuild):

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "kiro": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Kiro Gateway",
      "options": {
        "baseURL": "http://127.0.0.1:8000/v1",
        "apiKey": "<tu PROXY_API_KEY>"
      },
      "models": {
        "auto": { "name": "Auto (Kiro elige y ahorra tokens)" },
        "claude-sonnet-5": { "name": "Claude Sonnet 5 (preview)" },
        "claude-opus-4.8": { "name": "Claude Opus 4.8" },
        "claude-opus-4.7": { "name": "Claude Opus 4.7" },
        "claude-opus-4.6": { "name": "Claude Opus 4.6" },
        "claude-sonnet-4.6": { "name": "Claude Sonnet 4.6" },
        "claude-opus-4.5": { "name": "Claude Opus 4.5" },
        "claude-sonnet-4.5": { "name": "Claude Sonnet 4.5" },
        "claude-sonnet-4": { "name": "Claude Sonnet 4" },
        "claude-haiku-4.5": { "name": "Claude Haiku 4.5" },
        "deepseek-3.2": { "name": "DeepSeek V3.2 (preview)" },
        "minimax-m2.5": { "name": "MiniMax M2.5" },
        "minimax-m2.1": { "name": "MiniMax M2.1 (preview)" },
        "glm-5": { "name": "GLM 5" },
        "qwen3-coder-next": { "name": "Qwen3 Coder Next (preview)" }
      }
    }
  },
  "model": "kiro/auto",
  "small_model": "kiro/claude-haiku-4.5"
}
```

**Importante sobre el modelo `auto`:** úsalo con el ID literal `"auto"`, **no**
`"auto-kiro"`. La guía original de kiro-gateway sugiere `"auto-kiro"` como
alias amigable, pero la versión actual del gateway tiene un bug real: ese
alias solo se resuelve en el endpoint de listado (`/v1/models`), no en el
código que arma la petición de chat — así que `auto-kiro` se manda tal cual a
Kiro y lo rechaza ("Invalid model ID..."). El ID real `auto` sí funciona
perfecto (confirmado con una respuesta real del modelo). Detalle completo del
bug en `CLAUDE.md`.

**Para agregar otro modelo** (con el gateway corriendo, para ver los IDs
reales disponibles en esta cuenta):

```bash
curl -s http://127.0.0.1:8000/v1/models -H "Authorization: Bearer <tu PROXY_API_KEY>" | jq -r '.data[].id'
```

Agrega el ID que quieras dentro de `"models": { ... }` en el JSON de arriba,
p.ej. `"deepseek-3.2": { "name": "DeepSeek V3.2" }`, y guarda — `opencode
models kiro` lo reconoce al instante, sin reiniciar nada. Ten en cuenta que
esta lista **es estática** (ver nota de arriba sobre `/v1/models`): puede no
incluir modelos nuevos que tu cuenta ya tiene (confirmado: en julio 2026 la
cuenta ya tenía acceso real a `claude-sonnet-5` y `claude-opus-4.8` que el
gateway no listaba). Para saber con certeza qué modelos tiene tu cuenta *hoy*,
la fuente confiable es Kiro IDE mismo, no `/v1/models` del gateway — sus logs
registran cada respuesta real de `ListAvailableModelsCommand`:

```bash
grep -h '"commandName":"ListAvailableModelsCommand"' ~/.config/Kiro/logs/*/window1/exthost/kiro.kiroAgent/q-client.log | tail -1 | \
  python3 -c "import sys,json; l=sys.stdin.read(); d=json.loads(l[l.find('{'):]); [print(m['modelId']) for m in d['output']['models']]"
```

(La configuración actual ya incluye los 15 modelos —`auto` más 14— que esa
consulta devolvió al momento de escribir esto: familia Claude completa desde
Sonnet 4 hasta Opus 4.8/Sonnet 5, DeepSeek, MiniMax, GLM y Qwen. Todos
probados con una respuesta real, no solo listados.)

**Para agregar otro provider** (no solo otro modelo de Kiro): opencode
soporta múltiples entradas bajo `"provider"` en el mismo `config.json`, cada
una con su propio `baseURL`/`apiKey`/`models` — el bloque `"kiro"` de arriba
es la plantilla a copiar y ajustar.

### Desinstalar

```bash
# 1. Quita la línea `./modules/home/kiro-gateway.nix` de home.nix, hm-switch.
# 2. Borra el código/venv/secretos (no están versionados, es seguro):
rm -rf ~/dev/shared/kiro-gateway ~/.config/opencode
```

---

## Edición 3D / Video

Stack de creación audiovisual pensado para competir con Adobe (Premiere,
After Effects, Photoshop) aprovechando la **RTX 4050 (6 GB VRAM)** de
`victus` en modo **PRIME offload** (`hosts/victus/default.nix` —
`hardware.nvidia.prime.offload`, incluido `enableOffloadCmd`, que provee el
comando `nvidia-offload <app>` usado por los lanzadores de abajo).

| Adobe | Aquí | Instalado vía |
|---|---|---|
| Premiere + Color | **DaVinci Resolve** (gratis) | `modules/home/creative-suite.nix` (`davinci-resolve`) |
| After Effects (compositing) | **Fusion** (dentro de Resolve) | — |
| Cinema4D / 3D | **Blender** (CUDA/OptiX reales) | `modules/home/blender-gpu.nix` (standalone) |
| NLE ligero / respaldo | **Kdenlive** | `modules/home/creative-suite.nix` (`kdePackages.kdenlive`) |
| Photoshop | **Krita** + **GIMP 3** | `modules/home/creative-suite.nix` (`krita`, `gimp`) |
| Illustrator | **Inkscape** | `modules/home/creative-suite.nix` (`inkscape`) |

**Todo este stack es opt-in por host** (ver `flake.nix`, `hostExtraHomeModules`/`mkHost`): solo `victus` lo importa, porque es la única máquina con GPU dedicada. Un host sin GPU discreta (p. ej. `thinkpad`) usa `home.nix` a secas y no instala nada de esto.

**Importante sobre Blender:** el paquete `blender` de nixpkgs se compila
**sin ningún backend GPU de Cycles** (confirmado en su derivación:
`WITH_CYCLES_CUDA_BINARIES=FALSE`, `WITH_CYCLES_DEVICE_OPTIX=FALSE`) — con
él, Preferences > System solo lista "None"/"CUDA" y CUDA no encuentra ningún
dispositivo, aunque la GPU esté sana. Por eso `modules/home/blender-gpu.nix`
descarga (una sola vez, versión+hash fijados a mano, checksum SHA-256
verificado) el **build oficial de blender.org** a `~/.local/opt/blender`,
que sí trae esos kernels precompilados — mismo patrón dual que
opencode/claude (standalone como primario en PATH, el paquete de Nix en
`home.nix` queda como respaldo CPU-only/reproducible).

### Lanzadores (definidos en `modules/home/zsh.nix`)

```bash
resolve       # DaVinci Resolve, forzado a la RTX + XWayland (QT_QPA_PLATFORM=xcb)
blender-gpu   # Blender standalone, forzado a la RTX + fix de LD_LIBRARY_PATH (ver abajo)
```

`kdenlive`, `krita`, `gimp` e `inkscape` no necesitan `nvidia-offload`: se
lanzan directo por su nombre normal. `blender` a secas también resuelve ya
al binario standalone (gana en PATH), pero sin el offload a la dGPU — para
render en GPU usa siempre `blender-gpu`.

**Nota:** estas funciones/PATH nuevas solo existen en terminales *abiertas
después* de correr `hm-switch` — si sigues en la misma terminal donde
corriste el switch, ábrela de nuevo.

**Lanzar Resolve/Blender desde rofi (drun) también funciona**, no solo desde
terminal: `modules/home/gpu-launchers.nix` sobreescribe los `.desktop` de
ambas apps (mismo nombre de archivo que el original, prioridad alta vía
`xdg.desktopEntries` + `lib.hiPrio`) para que también lleven
`nvidia-offload`/XWayland/`LD_LIBRARY_PATH` — un `.desktop` a secas no pasa
por zsh, así que sin esto rofi lanzaba las apps sin ninguno de esos fixes
(Resolve fallaba bajo Wayland nativo; Blender abría el binario CPU-only de
Nix en vez del standalone). El de Blender usa ruta absoluta a
`~/.local/opt/blender/blender` a propósito: el PATH de la sesión gráfica
(el que usa rofi) no es el de zsh, así que un `Exec=blender` a secas ahí
habría vuelto a resolver al paquete de Nix.

**El fix de `LD_LIBRARY_PATH` en `blender-gpu`, explicado:** el loader
interno de Blender para CUDA (CUEW) hace `dlopen("libcuda.so")` en runtime.
NixOS no expone esa librería en una ruta estándar — vive en
`/run/opengl-driver/lib` — así que sin agregarla al `LD_LIBRARY_PATH` del
proceso, Blender no la encuentra aunque exista en el sistema. Confirmado:
sin el fix, Preferences > System solo lista "None"; con él, lista **OptiX**
y **CUDA** con la RTX 4050 real.

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
- **Actualizar la versión de Blender standalone:** edita `blenderVersion` y
  `blenderSha256` en `modules/home/blender-gpu.nix` (el hash real se saca del
  `blender-X.Y.Z.sha256` que publica `download.blender.org/release/`), borra
  `~/.local/opt/blender` y corre `hm-switch` — se re-descarga y verifica solo.

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
| **IA / Agentes** | Claude Code, Codex (OpenAI CLI), Kiro, Kiro CLI, OpenCode |
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

### Aliases útiles

```bash
ls / ll / la / lla / tree   # eza con iconos
v                            # neovim
c                            # clear
ff                           # fastfetch
nix-switch                   # reconstruir sistema
hm-switch                    # reconstruir solo perfil de usuario
nix-clean                    # liberar espacio (garbage collect + optimize)
pritunl                      # abre la GUI de Pritunl VPN
```

### VPN Pritunl

El cliente Pritunl (`pritunl-client`) se instala a nivel de **sistema**
(`modules/system/pritunl.nix`, importado globalmente desde
`modules/system/core.nix`, así que está disponible en cualquier host del
repo) — no hace falta descargar nada a mano ni AppImages: nixpkgs ya trae el
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

El sistema fuerza el login por cuenta `claude.ai` (sin API key):

```bash
claude auth login   # primera vez
claude              # usar normalmente
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
nix flake update        # actualizar todas las dependencias (actualiza flake.lock)
nix flake metadata      # info de entradas y revisiones
nix develop             # entrar al devShell manualmente (sin direnv)
nix build               # construir el output por defecto
```

### Actualizar las dependencias del sistema

```bash
cd ~/nixos-config
nix flake update        # actualiza nixpkgs, home-manager, catppuccin
nix-switch              # aplica las actualizaciones
```

---

## Agregar una nueva máquina

1. Crear `hosts/<nombre>/default.nix`:

```nix
{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/system/core.nix
    ../../modules/system/ai-helper.nix
    ../../modules/system/display-manager.nix
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

3. El host aparece automáticamente en `nixosConfigurations` (via `hostIfReady` en `flake.nix`).

4. Desplegar:

```bash
sudo nixos-rebuild switch --flake .#<nombre>
```

---

## Comandos de mantenimiento

```bash
# Liberar generaciones viejas y optimizar el store
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
