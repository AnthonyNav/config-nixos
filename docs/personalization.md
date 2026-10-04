# Personalización compartida

Desktop y Victus reciben los mismos presets Catppuccin. Mocha y Latte usan la
paleta oficial, con lavanda como acento, Rubik en la interfaz y JetBrains Mono
en terminal/código. Las plantillas de Caelestia sincronizan Hyprland, Kitty,
Rofi y Starship. El login SDDM conserva su tema oscuro independiente de sesión.

## Perfiles

Después de desplegar el `main` revisado, desde la terminal:

```sh
desktop-preset list
desktop-preset status
desktop-preset apply diario
desktop-preset apply claro
desktop-preset apply enfoque
```

| Perfil | Color | Comportamiento |
|---|---|---|
| Diario | Mocha, lavanda | Transparencia moderada, barra con iconos y fecha |
| Claro | Latte, lavanda | Superficies opacas y texto con contraste |
| Enfoque | Mocha, lavanda | Barra compacta, superficies opacas, animaciones desactivadas |

Los perfiles modifican únicamente los campos de apariencia definidos en
`modules/home/caelestia-presets.nix`. Conservan fuentes personalizadas, favoritos,
acciones propias, wallpapers y preferencias de Nexus. Tampoco modifican las
identidades Git/AWS ni los perfiles de energía. «No molestar» es una acción
independiente; elegir Enfoque no altera silenciosamente las notificaciones.

La activación añade valores ausentes y acciones nuevas a `shell.json`, sin
reemplazar valores existentes. `desktop-preset apply` cambia explícitamente los
campos del perfil. Los archivos se validan antes de escribir, se reemplazan de
forma atómica y conservan una copia anterior `.appearance-backup` con modo 0600.
Se rechazan JSON inválido y destinos/copias enlazados simbólicamente. Si falla
la CLI o sus archivos de colores quedan desactualizados, se recuperan el JSON,
el perfil y los archivos de tema anteriores. Efectos ya enviados a aplicaciones
abiertas o GTK pueden requerir volver a seleccionar el tema anterior; no se
promete una transacción entre procesos gráficos.

## Acciones del launcher

Abrir con `Super+R` y escribir `>` muestra acciones. Buscar «Perfil», «Luz
cálida», «No molestar», «Audio», «Diagnóstico del equipo», «Monitores» o «Captura
con anotación». Calculadora, esquemas, variantes, wallpapers y Nexus siguen
disponibles. Las acciones personales existentes se conservan, incluso si su
nombre coincide con una acción de la flota.

Aplicaciones y acciones externas se lanzan en `app.slice` mediante argumentos
literales, fuera de los límites de memoria del shell. Las acciones internas de
sesión y autocompletado mantienen su flujo nativo. `workstation-doctor` consulta
servicios y memoria sin llamar a Docker ni consultar la GPU.

Los favoritos iniciales son Firefox, Kitty y Thunar. Nexus permite cambiar
favoritos, fuentes, iconos del workspace, reloj de escritorio, densidad y opciones
por monitor. `dashboard.performance.showGpu` parte desactivado y los recursos se
actualizan cada tres segundos; habilitar el indicador GPU es una elección local,
no una prueba de que exista un trabajo GPU activo.

## Fondos y propietarios

`~/Pictures/Wallpapers/Fleet-Catppuccin` contiene tres imágenes de
[themed-wallpapers](https://github.com/yukazakiri/themed-wallpapers) fijadas por
revisión y hash individual en `packages/catppuccin-wallpapers.nix`. Nix las
descarga al construir. Las carpetas personales y las colecciones descargadas
por generaciones anteriores se conservan.

El selector nativo administra el fondo estático común. Animaciones, fondos por
monitor y un perfil Creativo específico quedan para una ampliación posterior
con medición de recursos. Las políticas declaradas de monitor-layout y el único
locker Caelestia permanecen como propietarios de sus respectivas funciones.

Home Manager administra plantillas y comandos; Caelestia administra los archivos
renderizados en `~/.local/state/caelestia/theme/`. Starship conserva una
configuración estática de respaldo, pero `STARSHIP_CONFIG` apunta a la versión
renderizada. Un shell ya abierto puede conservar su variable anterior: abre una
terminal nueva después del despliegue.

Kitty acepta las recargas por su socket local; el control remoto mediante
secuencias emitidas en la terminal queda deshabilitado (`socket-only`).

## Validación

`desktop-appearance` prueba preferencias personales, acciones, idempotencia,
JSON inválido, symlinks, recuperación tras fallo y plantillas desactualizadas.
Valida ambas paletas y el contraste del texto principal y del texto sobre el
acento, ejercita la CLI real con colores guardados y otro esquema nativo, y
hace que Starship lea los TOML resultantes. `caelestia-launchers`
ejercita las funciones QML realmente parcheadas, incluidos argumentos con
espacios, variables literales y entradas que requieren terminal.

Después del despliegue autorizado desde main, comprobar ambos modos/presets,
Nexus tras reiniciar, selector de fondos, Rofi/clipboard, terminales nuevas y
existentes, Wi-Fi, bloqueo, suspensión y monitores en ambos equipos. Medir una
sesión larga: los límites de memoria contienen el crecimiento del shell, no
demuestran que el problema upstream esté resuelto.
