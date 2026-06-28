# NixOS Multi-Host Dev Environment

Configuración modular de NixOS + Flakes + Home Manager orientada a desarrollo diario con escritorio Wayland (Hyprland), herramientas modernas de IA y soporte multi-máquina.

---

## Índice

- [Máquinas soportadas](#máquinas-soportadas)
- [Despliegue rápido](#despliegue-rápido)
- [Atajos de teclado](#atajos-de-teclado)
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
| `Super + R` | Lanzador de apps (Rofi) |
| `Super + B` | Firefox |
| `Super + T` | Thunar (gestor de archivos) |

### Ventanas

| Atajo | Acción |
|---|---|
| `Super + Q` / `Super + C` | Cerrar ventana activa |
| `Super + F` | Pantalla completa |
| `Super + E` | Flotante / Tiled |
| `Super + G` | Agrupar ventanas |
| `Super + Tab` | Cambiar en el grupo activo |
| `Super + ←↑↓→` | Mover foco entre ventanas |
| `Super + Shift + ←↑↓→` | Mover ventana físicamente |
| `Super + S` | **Modo resize** (flechas redimensionan, Escape/Enter salen) |

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
| `Super + Escape` | Menú de energía (wlogout) — apagar, reiniciar, suspender, cerrar sesión |
| `Super + M` | Salir de Hyprland sin menú (emergencia) |

### Notificaciones

| Atajo | Acción |
|---|---|
| `Super + N` | Abrir/cerrar panel de notificaciones (SwayNC) |
| `Super + Shift + N` | Activar / desactivar No molestar |
| `Super + Alt + N` | Limpiar todas las notificaciones |

### Productividad

| Atajo | Acción |
|---|---|
| `Super + V` | Historial del portapapeles (cliphist → Rofi) |
| `Super + Shift + S` | Captura de área → portapapeles |
| `Print` | Captura completa → `~/Pictures/Screenshots/` |
| `Super + Shift + P` | Selector de color (hyprpicker) |
| `Super + Shift + K` | Cheatsheet de todos los atajos activos (Rofi) |

### Teclado

| Atajo | Acción |
|---|---|
| `Shift izq + Shift der` | Alternar entre teclado inglés (us) y español latinoamericano |

> El LED de Scroll Lock indica qué layout está activo.

### Waybar — módulo de rendimiento

Clic izquierdo sobre el icono en la barra cicla entre tres perfiles de energía:

| Icono | Perfil |
|---|---|
| `󰓅` | Balanceado |
| `󱐌` | Máximo rendimiento |
| `󰌪` | Ahorro de energía |

### Luz nocturna (terminal)

```bash
night-soft   # 4200K suave
night-warm   # 3200K cálido
night-off    # desactivar
night-auto   # restaurar el servicio automático (wlsunset)
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
