# NixOS Multi-Host Dev Environment

Configuración modular de NixOS + Flakes + Home Manager orientada a desarrollo diario con escritorio Wayland (Hyprland), herramientas modernas de IA y soporte multi-máquina.

---

## Índice

- [Máquinas soportadas](#máquinas-soportadas)
- [Despliegue rápido](#despliegue-rápido)
- [Atajos de teclado](#atajos-de-teclado)
- [Escritorio (Caelestia Shell)](#escritorio-caelestia-shell)
- [Kiro Gateway + opencode](#kiro-gateway--opencode)
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
        "claude-opus-4.7": { "name": "Claude Opus 4.7" },
        "claude-opus-4.6": { "name": "Claude Opus 4.6" },
        "claude-opus-4.5": { "name": "Claude Opus 4.5" },
        "claude-sonnet-4.6": { "name": "Claude Sonnet 4.6" },
        "claude-sonnet-4.5": { "name": "Claude Sonnet 4.5" },
        "claude-haiku-4.5": { "name": "Claude Haiku 4.5" }
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
la fuente confiable es Kiro IDE mismo, no `/v1/models` del gateway.

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
pritunl                      # VPN Pritunl (AppImage)
```

### VPN Pritunl

El cliente Pritunl se instala como AppImage (una sola vez):

```bash
curl -fsSL https://github.com/pritunl/pritunl-client-electron/releases/latest/download/Pritunl.AppImage \
  -o ~/.local/bin/pritunl-client.AppImage && chmod +x ~/.local/bin/pritunl-client.AppImage
```

Luego, cada vez que se necesite:

```bash
pritunl
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
