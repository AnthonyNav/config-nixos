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
  # Si algún día se reemplaza/mueve alguno de estos monitores, usa
  # `set-monitor` para volver a encontrar la posición/rotación correcta y
  # actualiza estos valores a mano (ver README.md, "Monitores externos").
  wayland.windowManager.hyprland.settings.monitor = [
    "HDMI-A-1,preferred,0x0,1"
    "DP-3,preferred,-1080x0,1,transform,1"
    "DP-1,preferred,2560x0,1,transform,3"
  ];
}
