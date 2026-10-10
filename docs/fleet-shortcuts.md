# Fleet: teclado y escritorio

M = Command en Mac, Super en Linux. Alt = Option en Mac.
Caps Lock conserva su función; AltGr conserva los símbolos.

Las acciones de aplicaciones usan Command nativo en Mac y Super en las aplicaciones Linux compatibles.
Los atajos Ctrl de Linux siguen disponibles. Una aplicación desconocida conserva sus controles.

| Frecuencia | Acción | Atajo |
|---|---|---|
| Muy alta | Copiar | M+C |
| Muy alta | Pegar | M+V |
| Alta | Cortar | M+X |
| Muy alta | Deshacer | M+Z |
| Alta | Rehacer | M+Shift+Z |
| Alta | Seleccionar todo | M+A |
| Muy alta | Guardar | M+S |
| Alta | Buscar | M+F |
| Media | Abrir archivo | M+O |
| Media | Nuevo documento | M+N |
| Alta | Nueva pestaña | M+T |
| Alta | Cerrar pestaña/documento | M+W |
| Media | Salir normalmente de la aplicación | M+Q |
| Alta | Dirección/búsqueda del navegador | M+L |
| Alta | Recargar navegador | M+R |

VSCode: sólo el contexto correspondiente recibe cada atajo.

| Acción | Atajo |
|---|---|
| Abrir archivo rápidamente | M+P |
| Paleta de comandos | M+Shift+P |
| Buscar en proyecto | M+Shift+F |
| Panel inferior | M+J |
| Inicio/final de línea (editor) | M+← / → |
| Seleccionar hasta inicio/final de línea (editor) | M+Shift+← / → |

Terminal: M+C copia selección; M+V pega. Ctrl+C interrumpe, Ctrl+Z suspende y Ctrl+D conserva su función.
Super+Z nunca se traduce a Ctrl+Z en una terminal. TUI y SSH conservan sus controles.

Abre el menú con M+Alt+Enter o `fleet-menu`; suelta los modificadores antes de elegir.
En Mac, una aplicación con ese atajo nativo conserva prioridad.

| Tecla del menú | Acción |
|---|---|
| left | Enfocar a la izquierda |
| right | Enfocar a la derecha |
| up | Enfocar arriba |
| down | Enfocar abajo |
| 1 | Escritorio 1 |
| 2 | Escritorio 2 |
| 3 | Escritorio 3 |
| 4 | Escritorio 4 |
| 5 | Escritorio 5 |
| 6 | Escritorio 6 |
| 7 | Escritorio 7 |
| 8 | Escritorio 8 |
| 9 | Escritorio 9 |
| 0 | Escritorio 10 |
| T | Terminal |
| B | Navegador |
| A | Archivos |
| O | Orca |
| F | Pantalla completa |
| E | Mosaico / flotante |
| M | Modo mover: flechas y escritorios |
| R | Modo redimensionar: flechas |
| C | Opciones de captura |
| G | Opciones de grabación |
| L | Bloquear |
| K | Guía de atajos |
| Escape | Cancelar |

Mover: flechas mueven; 1–9/0 envían al escritorio 1–10. Redimensionar: flechas cambian tamaño.
Enter/Escape termina el modo y retira su indicador. Las demás acciones cierran el menú.

M+Shift+3: pantalla; M+Shift+4: área; M+Shift+5: opciones de captura/grabación.
Mac conserva sus capturas nativas. El menú permite archivo o portapapeles sin una cuarta tecla.

Captura:

| Tecla | Acción |
|---|---|
| 3 | Pantalla → archivo |
| 4 | Área → archivo |
| W | Ventana → archivo |
| S | Pantalla → portapapeles |
| A | Área → portapapeles |
| C | Ventana → portapapeles |

Grabación:

| Tecla | Acción |
|---|---|
| A | Iniciar área, audio del equipo |
| S | Iniciar pantalla, audio del equipo |
| T | Detener mi grabación Fleet |
| E | Estado de la grabación |

Capturas: `~/Pictures/Screenshots`. Grabaciones: `~/Movies/ScreenRecordings`. Son archivos locales fuera de shared.
Grabación: audio del equipo por defecto; micrófono sólo con `--audio microphone`. `--audio none` graba sin audio.
Una sesión Fleet por usuario/equipo; `record stop` sólo detiene su propia sesión.
En Mac, `record probe --region x,y,w,h` debe comprobar vídeo, audio del equipo y parada antes de habilitar grabaciones.

```sh
fleet-ui screenshot area --clipboard
fleet-ui screenshot window --file auto
fleet-ui screenshot screen --monitor focused --file auto
fleet-ui record start --target area --audio system
fleet-ui record start --target screen --audio system
fleet-ui record status
fleet-ui record stop
```
