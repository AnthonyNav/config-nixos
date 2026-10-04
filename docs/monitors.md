# Monitores por topología, no por host

`monitor-layout.service` es el único automatismo. Se inicia y termina con la
sesión gráfica de Hyprland. Escucha su socket de eventos: arranque, conexión,
desconexión y recarga de configuración. Agrupa eventos durante 400 ms y sólo
aplica cambios si la geometría/modo difieren. No usa un timer ni polling.

## Selección

- Tres externos conocidos: LG central QHD a 99.95 Hz, laterales FHD a 165 Hz,
  izquierda 90° y derecha 270°. No depende de HDMI-A-1/DP-1/DP-3.
- Dos externos conocidos: conserva sus posiciones; si falta el LG, junta
  los dos laterales. Un panel interno activo se coloca debajo, a y=1920.
- Otras combinaciones, incluido portátil + dos externos: distribución horizontal
  con panel interno primero, preservando resolución/refresco/escala y sin
  adivinar orientación física. No se limita a tres pantallas.
- Identidades duplicadas o un modo requerido no anunciado: fallback genérico.
  Pantallas deshabilitadas no se encienden. No se apagan pantallas deliberadamente.

Las identidades están en `inventory/displays.nix` (make/model/serial).
Los EDID actuales son LG IPS QHD, XXX CR270C-P y HGC CR270C. Los conectores y
las descripciones del módulo fijo anterior estaban desactualizados.
`Unknown` representa un serial ausente; no permite distinguir dos paneles
idénticos sin serial. En ese caso se evita el perfil conocido.

## Uso después de desplegar main

```sh
monitor-auto status
monitor-layout --dry-run       # consulta y muestra; no escribe en Hyprland
monitor-auto off
set-monitor left portrait DP-3 HDMI-A-1
monitor-auto on
journalctl --user -u monitor-layout.service -b
```

`set-monitor` valida primero y después pausa el automatismo antes de ajustar.
Si Hyprland rechaza el ajuste, informa el error y restaura el servicio sólo
si estaba activo; no comunica un éxito falso ni reactiva una pausa previa.
Con tres o más pantallas exige OUTPUT y ANCHOR. Los ajustes manuales duran la
sesión o hasta `monitor-auto on`; una nueva sesión recupera el servicio.
Los comandos Nix descartan el LD_LIBRARY_PATH heredado sólo para sus hijos.

## Por qué no Kanshi en esta integración

Se revisaron Home Manager y el fuente Kanshi 1.9.0: es una buena opción para
perfiles conocidos. El contrato de Hyprland 0.56.2 conserva estado de
wlr-output-management con prioridad sobre `hyprctl keyword monitor`; una
posición del perfil anterior puede persistir cuando el siguiente no la define.
Combinar Kanshi con un fallback/manual por IPC crea dos escritores y overrides
incompatibles. Aquí el controlador único por IPC permite geometría calculada
para pantallas desconocidas y una pausa explícita para ajustes manuales.

El bug de acknowledgements no-op reportado en 0.56.0 está corregido en el fuente
0.56.2; no se usa como argumento para descartar la versión actual de Kanshi.

## Aceptación física pendiente

Después de activar main con autorización, probar en cada equipo:

1. Sólo panel principal/interno, un externo y dos externos.
2. Rig de tres, cambio de conectores/dock, desconexión de cada pantalla y retorno.
3. Escalas fraccionales, 99.95/165 Hz reales, orientación de ambos laterales.
4. Suspensión/reanudación, bloqueo/DPMS, repintado de Caelestia.
5. Ajuste manual, pausa/reactivación y nueva sesión.

Las pruebas automáticas cubren selección, cálculo, idempotencia y casos de
error; no certifican el montaje físico, EDID de Victus ni el comportamiento DRM.
