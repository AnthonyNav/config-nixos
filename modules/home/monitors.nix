{ pkgs, ... }:

{
  # set-monitor: posiciona (izquierda/derecha) y rota (paisaje/retrato) un
  # monitor externo recién conectado, sin depender de nombres de salida
  # fijos — los monitores externos varían según dónde te conectes (a
  # diferencia de kanshi, que necesita conocer el nombre/descripción exacta
  # de antemano). Lee el estado real vía `hyprctl monitors -j` en cada
  # invocación y aplica el cambio con `hyprctl keyword monitor` — es
  # puramente manual/bajo demanda (sin daemon, sin detección de hotplug),
  # tal como se pidió: NO reemplaza la regla global `monitor = ",
  # preferred, auto, 1"` de hyprland.nix, solo la sobreescribe en caliente
  # para la sesión actual. Al reconectar o reiniciar, esa regla wildcard
  # vuelve a aplicarse y hay que volver a correr set-monitor (ver
  # README.md, "Monitores externos").
  #
  # Real ejecutable vía home.packages (no función de zsh): mismo motivo
  # documentado para theme-* en theme-mode.nix — así puede invocarse también
  # desde un bind de Hyprland (exec corre por sh -c, no zsh; ver zsh.nix).
  home.packages = [
    (pkgs.writeShellApplication {
      name = "set-monitor";
      runtimeInputs = [ pkgs.jq pkgs.hyprland pkgs.libnotify pkgs.coreutils ];
      text = ''
        usage() {
          cat >&2 <<'EOF'
        Uso: set-monitor <left|right> [normal|portrait|portrait-inv] [OUTPUT] [ANCHOR]

          left|right     posición de OUTPUT respecto al ancla
          normal         (default) horizontal, sin rotar
          portrait       rotación 90° (transform=1)
          portrait-inv   rotación 270°/90° inversa (transform=3) — probar
                         esta si "portrait" queda al revés en tu monitor
          OUTPUT         nombre exacto del monitor a mover (columna .name
                         de `hyprctl monitors -j`) — obligatorio si hay
                         más de 2 monitores conectados
          ANCHOR         nombre exacto del monitor de referencia — obligatorio
                         si hay más de 2 monitores conectados. Con solo 2, se
                         detecta solo (eDP-1 si está presente, si no el otro
                         monitor conectado) porque no hay ambigüedad posible.
                         Con 3+ monitores NO se adivina (antes caía en "el
                         monitor con foco", que cambia solo con mover el
                         mouse — daba resultados distintos en cada llamada):
                         pásalo siempre explícito.

        Ejemplos (2 monitores, auto-detección):
          set-monitor right
          set-monitor left portrait

        Ejemplo (3 monitores: centro HDMI-A-1, dos laterales en vertical):
          set-monitor left  portrait DP-3 HDMI-A-1
          set-monitor right portrait DP-1 HDMI-A-1
        EOF
        }

        if [ "$#" -lt 1 ]; then
          usage
          exit 1
        fi

        position="$1"
        rotation="''${2:-normal}"
        explicit_target="''${3:-}"
        explicit_anchor="''${4:-}"

        case "$position" in
          left | right) ;;
          *)
            echo "Posición inválida: $position (usa left o right)" >&2
            usage
            exit 1
            ;;
        esac

        transform=0
        case "$rotation" in
          normal) transform=0 ;;
          portrait) transform=1 ;;
          portrait-inv) transform=3 ;;
          *)
            echo "Rotación inválida: $rotation" >&2
            usage
            exit 1
            ;;
        esac

        if ! monitors_json="$(hyprctl monitors -j 2>/dev/null)"; then
          echo "hyprctl monitors falló — ¿estás dentro de una sesión de Hyprland?" >&2
          exit 1
        fi

        count="$(jq 'length' <<<"$monitors_json")"

        if [ "$count" -lt 2 ]; then
          echo "Solo hay $count monitor(es) conectado(s) — conecta el monitor externo antes de correr set-monitor." >&2
          exit 1
        fi

        list_monitors() {
          jq -r '.[] | "  \(.name)\t\(.description)"' <<<"$monitors_json" >&2
        }

        validate_name() {
          local n="$1"
          if ! jq -e --arg n "$n" '.[] | select(.name == $n)' <<<"$monitors_json" >/dev/null; then
            echo "No existe un monitor llamado '$n'. Conectados:" >&2
            list_monitors
            exit 1
          fi
        }

        # Con 3+ monitores no hay forma segura de adivinar ni el objetivo ni
        # el ancla: la versión anterior caía en "el monitor con foco" cuando
        # faltaba el ancla, y el foco cambia con solo mover el mouse — cada
        # llamada terminaba anclando contra un monitor distinto sin avisar,
        # produciendo posiciones incoherentes. Con 3+, ambos son obligatorios.
        if [ "$count" -gt 2 ] && { [ -z "$explicit_target" ] || [ -z "$explicit_anchor" ]; }; then
          echo "Hay $count monitores conectados — con 3 o más, pasa OUTPUT y ANCHOR explícitos (ver 'set-monitor' sin argumentos para ejemplos). Conectados:" >&2
          list_monitors
          exit 1
        fi

        if [ -n "$explicit_target" ]; then
          validate_name "$explicit_target"
          target_name="$explicit_target"
        else
          target_name=""
        fi

        if [ -n "$explicit_anchor" ]; then
          validate_name "$explicit_anchor"
          if [ "$explicit_anchor" = "$target_name" ]; then
            echo "OUTPUT y ANCHOR no pueden ser el mismo monitor ($explicit_anchor)." >&2
            exit 1
          fi
          anchor_name="$explicit_anchor"
        else
          # Solo llega aquí con exactamente 2 monitores conectados: no hay
          # ambigüedad, el ancla es el otro monitor (eDP-1 si es uno de los
          # dos, si no da igual cuál se llame "ancla").
          anchor_name="$(jq -r --arg t "$target_name" '
            ([.[] | select(.name != $t)]) as $rest |
            (
              ($rest[] | select(.name == "eDP-1") | .name)
              // ($rest[0].name)
            )
          ' <<<"$monitors_json")"
        fi

        if [ -z "$target_name" ]; then
          target_name="$(jq -r --arg a "$anchor_name" '.[] | select(.name != $a) | .name' <<<"$monitors_json")"
        fi

        read -r anchor_x anchor_y anchor_w anchor_h anchor_scale anchor_transform <<<"$(
          jq -r --arg a "$anchor_name" \
            '.[] | select(.name == $a) | "\(.x) \(.y) \(.width) \(.height) \(.scale) \(.transform)"' \
            <<<"$monitors_json"
        )"
        read -r target_w target_h <<<"$(
          jq -r --arg t "$target_name" '.[] | select(.name == $t) | "\(.width) \(.height)"' <<<"$monitors_json"
        )"

        # Tamaño lógico del ancla (respeta su escala actual, que este script
        # no toca, y su rotación actual, por si el ancla ya está en
        # portrait). El objetivo se aplica siempre con escala 1 (mismo
        # convenio que el wildcard global en hyprland.nix), así que su
        # tamaño lógico es el tamaño físico crudo, intercambiando ancho/alto
        # si va a quedar en retrato (transform 1 o 3 rota el bounding box).
        if [ "$anchor_transform" = "1" ] || [ "$anchor_transform" = "3" ]; then
          anchor_logical_w="$(awk -v w="$anchor_h" -v s="$anchor_scale" 'BEGIN { printf "%d", w / s }')"
        else
          anchor_logical_w="$(awk -v w="$anchor_w" -v s="$anchor_scale" 'BEGIN { printf "%d", w / s }')"
        fi

        if [ "$transform" = "1" ] || [ "$transform" = "3" ]; then
          target_logical_w="$target_h"
        else
          target_logical_w="$target_w"
        fi

        target_y="$anchor_y"
        if [ "$position" = "right" ]; then
          target_x="$((anchor_x + anchor_logical_w))"
        else
          target_x="$((anchor_x - target_logical_w))"
        fi

        hyprctl keyword monitor "$target_name,preferred,''${target_x}x''${target_y},1,transform,$transform"

        # En este hardware, aplicar un transform puede hacer que el backend
        # DRM cicle brevemente el conector (visto en hyprland.log: connector
        # disconnected → reconnected). Durante ese instante,
        # Hyprland.monitorFor(screen) de Quickshell puede devolver null para
        # esa pantalla, y la barra de Caelestia se queda sin repintar hasta
        # la próxima interacción manual (confirmado: abrir el launcher con
        # Super+R la recupera). Este sleep + toggle abre y cierra el
        # launcher automáticamente para forzar ese mismo repintado sin que
        # tengas que hacerlo tú.
        sleep 0.3
        caelestia shell drawers toggle launcher >/dev/null 2>&1 || true
        sleep 0.15
        caelestia shell drawers toggle launcher >/dev/null 2>&1 || true

        notify-send "set-monitor" "$target_name → $position de $anchor_name ($rotation)" || true
      '';
    })
  ];
}
