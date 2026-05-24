# NixOS Multi-Host Dev Environment

Configuracion modular de NixOS + Flakes + Home Manager orientada a desarrollo diario, escritorios Wayland con Hyprland y herramientas modernas de IA.

Este repositorio esta pensado para compartir el 90% de la configuracion entre varias maquinas y dejar las diferencias de hardware dentro de `hosts/`.

## 🚀 Requisitos Previos E Instalacion Rapida

### 1. Clonar el repositorio en `~/nixos-config`

```bash
git clone <TU-URL-DEL-REPO> ~/nixos-config
cd ~/nixos-config
```

### 2. Ajustar el usuario si no vas a usar `anthony`

La configuracion centraliza el usuario principal en una sola linea dentro de [`flake.nix`](./flake.nix):

```nix
username = "anthony";
```

Si tu usuario local es otro, cambia ese valor antes del primer despliegue. Ese cambio alimenta:

- El usuario de NixOS
- La configuracion de Home Manager
- El `homeDirectory`
- El wrapper de Hyprland para el wallpaper
- La salida standalone de Home Manager

### 3. Flujo para una maquina nueva

Cada host vive en su propia carpeta dentro de `hosts/`:

- `hosts/victus/`
- `hosts/thinkpad/`
- `hosts/desktop/`

`victus` ya incluye su `hardware-configuration.nix`. `thinkpad` y `desktop` quedan listos en cuanto agregues el suyo.

#### Opcion A: ya arrancaste la maquina con un NixOS base

Clona el repo y genera el hardware file del host correcto:

```bash
cd ~/nixos-config
sudo nixos-generate-config --show-hardware-config > hosts/thinkpad/hardware-configuration.nix
```

O para la desktop:

```bash
cd ~/nixos-config
sudo nixos-generate-config --show-hardware-config > hosts/desktop/hardware-configuration.nix
```

#### Opcion B: estas en el instalador y tu sistema raiz esta montado en `/mnt`

```bash
sudo nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix ~/nixos-config/hosts/thinkpad/hardware-configuration.nix
```

### 4. Desplegar el sistema con Flakes

Desde la raiz del repo:

```bash
cd ~/nixos-config
sudo nixos-rebuild switch --flake .#victus
```

Para otras maquinas:

```bash
sudo nixos-rebuild switch --flake .#thinkpad
sudo nixos-rebuild switch --flake .#desktop
```

### 5. Alias y comandos rapidos ya incluidos

La shell Zsh define estas funciones:

```bash
nix-switch
hm-switch
```

#### `nix-switch`

- Detecta el hostname actual con `hostnamectl --static`
- Ejecuta `sudo nixos-rebuild switch --flake "path:$HOME/nixos-config#<hostname>"`
- No depende de que los archivos nuevos ya esten rastreados por Git

Funciona perfecto si el hostname de la maquina coincide con la carpeta del host, por ejemplo `victus`, `thinkpad` o `desktop`.

#### `hm-switch`

- Ejecuta `home-manager switch --flake "path:$HOME/nixos-config#$(id -un)"`
- Si `home-manager` todavia no existe en el `PATH`, usa `nix run github:nix-community/home-manager -- switch --flake ...`
- Funciona aunque tengas archivos nuevos sin `git add`

### 6. Root y Home Manager: flujo recomendado

En este repo, Home Manager esta integrado dentro de cada `nixosConfiguration`. Eso significa que el comando principal recomendado es:

```bash
sudo nixos-rebuild switch --flake .#victus
```

Ese rebuild aplica:

- Configuracion del sistema
- Paquetes globales
- Servicios
- Tu perfil de Home Manager

Si acabas de crear un archivo nuevo, por ejemplo `hosts/thinkpad/hardware-configuration.nix`, usa la variante `path:` o la funcion `nix-switch` para evitar la limitacion de los flakes basados en Git con archivos no rastreados:

```bash
sudo nixos-rebuild switch --flake "path:$PWD#thinkpad"
```

Ademas, el flake expone una salida standalone para Home Manager. Si ya tienes el sistema desplegado y solo quieres refrescar el entorno de usuario:

```bash
home-manager switch --flake .#anthony
```

O de forma generica:

```bash
home-manager switch --flake ".#$(id -un)"
```

Si el binario `home-manager` todavia no esta disponible en tu shell:

```bash
nix run github:nix-community/home-manager -- switch --flake "path:$PWD#$(id -un)"
```

## 🤖 Integracion De Inteligencia Artificial

### `nix-ld` habilitado globalmente

El modulo [`modules/system/ai-helper.nix`](./modules/system/ai-helper.nix) activa `programs.nix-ld.enable = true`, lo cual permite ejecutar binarios Linux genericos dinamicamente enlazados sin caer en errores tipicos de NixOS como:

```text
Could not start dynamically linked executable
```

Esto es especialmente util para:

- Claude Code
- Codex
- Kiro CLI
- OpenCode
- Instaladores nativos de herramientas de IA
- SDKs externos que no estan empaquetados de forma nativa para NixOS

Ademas, el entorno incluye utilidades de soporte para este tipo de software, como `appimage-run`, `patchelf`, `jq`, `file` y una coleccion mas amplia de librerias de runtime para binarios tipo Electron/AppImage.

### Compatibilidad con Kiro y OpenCode

El entorno ya queda razonablemente listo para estas herramientas:

- `Kiro IDE`: tu sistema actual usa glibc moderna, suficiente para los requisitos actuales de Kiro en Linux.
- `Kiro CLI`: funciona bien con binarios en `~/.local/bin` y autenticacion por navegador.
- `OpenCode`: se integra bien con terminales modernas como Kitty y con instalaciones via script o npm.

Instalaciones tipicas:

```bash
curl -fsSL https://opencode.ai/install | bash
curl -fsSL https://desktop-release.q.us-east-1.amazonaws.com/latest/kiro-cli.appimage -o ~/Downloads/kiro-cli.appimage
chmod +x ~/Downloads/kiro-cli.appimage
~/Downloads/kiro-cli.appimage
```

### Claude Code: suscripcion OAuth, no API keys

Este repo garantiza que `~/.claude/settings.json` contenga `forceLoginMethod = "claudeai"` sin destruir otras preferencias locales que ya existan en ese archivo.

Eso fuerza el flujo de autenticacion por cuenta de `claude.ai` y evita que el entorno quede orientado a facturacion por API Keys o Anthropic Console.

En otras palabras:

- El flujo esperado es suscripcion de Claude App
- La autenticacion es por navegador
- No necesitas exportar `ANTHROPIC_API_KEY` para uso interactivo

### Instalacion recomendada de Claude Code

Tienes dos rutas validas:

#### Opcion A: instalador nativo recomendado

```bash
curl -fsSL https://claude.ai/install.sh | bash
claude --version
claude doctor
```

#### Opcion B: instalacion via npm

```bash
npm config set prefix ~/.npm-global
npm install -g @anthropic-ai/claude-code
claude --version
claude doctor
```

### Inicio de sesion paso a paso

La CLI actual de Claude Code usa `claude auth login`. Si vienes de guias antiguas que mencionan `claude login`, usa este comando actualizado:

```bash
claude auth login
```

Flujo esperado:

1. La CLI abre el flujo OAuth para tu cuenta de `claude.ai`.
2. Se lanza tu navegador predeterminado. En esta configuracion Firefox ya viene instalado, asi que puedes validar la sesion ahi.
3. Inicias sesion con tu cuenta de suscripcion.
4. Claude Code recibe el callback OAuth o, si estas en SSH/WSL/contenedor, te pedira pegar el codigo de autorizacion manualmente.
5. El token queda gestionado por Claude Code en el espacio de usuario y fuera del repositorio, de forma que no terminas guardando secretos dentro de Git.

Comandos utiles:

```bash
claude auth status
claude auth logout
claude doctor
```

### Wrapper nativo de Zsh para `claude`

La configuracion de Zsh define una funcion `claude()` con este comportamiento:

- Si existe `~/.local/bin/claude`, usa la instalacion nativa
- Si no existe, intenta ejecutar el `cli.js` del paquete npm global usando `node`
- Esto evita depender de wrappers conflictivos y ayuda a sortear problemas de PATH o lanzadores con extensiones no deseadas en entornos Node.js modernos

Para el usuario final, el comando siempre es el mismo:

```bash
claude
```

## 💼 Entornos De Desarrollo Ultra-Rapidos Con Direnv

`direnv` y `nix-direnv` ya estan habilitados declarativamente. Eso significa que cada proyecto puede tener su propio stack aislado sin ensuciar el sistema global.

### Como funciona

1. Entras a una carpeta de proyecto
2. `direnv` detecta el archivo `.envrc`
3. `nix-direnv` construye o reutiliza el `devShell`
4. Tu terminal recibe automaticamente Node, Python, Flutter, .NET y cualquier otra herramienta declarada ahi
5. Sales de la carpeta y el entorno desaparece

### Plantilla rapida de `flake.nix` para un proyecto

```nix
{
  description = "DevShell poliglota";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            nodejs_22
            corepack
            python3
            flutter
            dotnet-sdk_8
            git
          ];

          shellHook = ''
            echo "Entorno listo"
            echo "Node: $(node --version)"
            echo "Python: $(python --version)"
            echo ".NET: $(dotnet --version)"
          '';
        };
      });
}
```

### Activacion instantanea

Dentro del proyecto:

```bash
printf 'use flake\n' > .envrc
direnv allow
```

Cada vez que vuelvas a entrar en esa carpeta, el entorno se cargara automaticamente.

## 🎨 Entorno Grafico: Hyprland + Waybar Liquid Glass

La interfaz de escritorio se construye sobre Hyprland, Waybar, Rofi y SwayNC con una estetica translucidada tipo liquid glass y tema Catppuccin.

### Atajos esenciales de Hyprland

| Accion | Atajo | Resultado |
| --- | --- | --- |
| Terminal | `Super + Enter` | Abre Kitty |
| Navegador | `Super + B` | Abre Firefox |
| Lanzador | `Super + R` | Abre Rofi en modo `drun` |
| Panel de notificaciones | `Super + N` | Alterna SwayNC |
| No molestar | `Super + Shift + N` | Activa o desactiva DND |
| Limpiar notificaciones | `Super + Alt + N` | Vacia el centro de notificaciones |
| Historial del portapapeles | `Super + V` | Abre `cliphist` via Rofi |
| Selector de color | `Super + Shift + P` | Copia el color seleccionado |
| Captura de area al portapapeles | `Super + Shift + S` | Selecciona un area y la copia |
| Captura completa a archivo | `Print` | Guarda en `~/Pictures/Screenshots/` |

### Workspaces dinamicos del 1 al 10

La navegacion de escritorios virtuales es directa:

- `Super + 1` a `Super + 9`: cambia al workspace 1 al 9
- `Super + 0`: cambia al workspace 10
- `Super + Shift + 1` a `Super + Shift + 9`: mueve la ventana activa al workspace 1 al 9
- `Super + Shift + 0`: mueve la ventana activa al workspace 10

Esto permite trabajar por contextos, por ejemplo:

- Workspace 1: terminales y shell
- Workspace 2: navegador
- Workspace 3: editor
- Workspace 4: documentacion
- Workspace 5+: pruebas, multimedia o sesiones efimeras

### Modulo de rendimiento por iconos en Waybar

La barra Waybar incluye un modulo `custom/performance` conectado a `power-profiles-daemon`.

Al hacer clic izquierdo sobre el icono, el perfil cicla asi:

1. `󰓅` Balanza: modo equilibrado
2. `󱐌` Rayo: maxima potencia
3. `󰌪` Hoja: ahorro de energia

Internamente, el widget ejecuta `powerprofilesctl` y muestra una notificacion con el modo nuevo. Es una forma rapida de pasar de bateria a rendimiento sin abrir paneles extra.

## Referencias Oficiales Recomendadas

- Claude Code setup: <https://docs.anthropic.com/en/docs/claude-code/setup>
- Claude Code CLI reference: <https://code.claude.com/docs/en/cli-usage>
- Claude Code troubleshoot install/login: <https://code.claude.com/docs/en/troubleshoot-install>
