{ ... }:

{
  # Layout fijo de 3 monitores del host `desktop`: uno central en horizontal
  # y dos laterales en vertical (retrato) — a diferencia de victus/thinkpad
  # (laptops que se conectan a monitores externos variables, ver
  # modules/home/monitors.nix y su comando manual `set-monitor`), este
  # escritorio siempre tiene los mismos 3 monitores conectados, así que tiene
  # sentido declararlo una vez en vez de correr `set-monitor` a mano después
  # de cada reinicio.
  #
  # Valores confirmados en vivo con `hyprctl monitors -j` tras ajustar con
  # `set-monitor` hasta que la orientación se viera correcta — importante:
  # los dos laterales NO usan la misma rotación (transform=1 vs transform=3),
  # depende del lado físico del cable/montaje de cada panel, no es simétrico:
  #   - HDMI-A-1 (centro, LG IPS QHD): 2560x1440 @ 0,0, sin rotar.
  #   - DP-3 (izquierda, HGC CR270C): 1920x1080 rotado 90° (transform=1),
  #     ancho lógico en vertical = 1080, por eso x = 0 - 1080 = -1080.
  #   - DP-1 (derecha, CR270C-P): 1920x1080 rotado 270° (transform=3),
  #     x = 0 + 2560 (ancho lógico del centro).
  #
  # Tasa de refresco fijada explícitamente en vez de "preferred": el modo
  # "preferred" del EDID resulta ser 60Hz en los tres paneles aunque
  # soportan más — confirmado con `hyprctl monitors -j | jq '.[].availableModes'`:
  #   - HDMI-A-1 (LG QHD): tope real 2560x1440@99.95Hz (no hay modo 120Hz).
  #   - DP-3: tope real 1920x1080@180Hz, pero también tiene un modo exacto
  #     a 165Hz.
  #   - DP-1: tope real 1920x1080@180Hz, pero a diferencia de DP-3 NO tiene
  #     modo de 144Hz (solo 120 o 165) — por eso se usa 165Hz en ambos
  #     laterales (el valor más alto que existe exacto en los dos paneles),
  #     no el tope absoluto de 180, para que quedaran parejos.
  #
  # Si algún día se reemplaza/mueve alguno de estos monitores, usa
  # `set-monitor` para volver a encontrar la posición/rotación correcta,
  # revisa sus `availableModes` de nuevo (pueden no coincidir aunque el
  # modelo se vea igual, como pasó aquí) y actualiza estos valores a mano
  # (ver README.md, "Monitores externos").
  wayland.windowManager.hyprland.settings.monitor = [
    "HDMI-A-1,2560x1440@99.95,0x0,1"
    "DP-3,1920x1080@165,-1080x0,1,transform,1"
    "DP-1,1920x1080@165,2560x0,1,transform,3"
  ];
}
