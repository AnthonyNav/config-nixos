#!/usr/bin/env python3
"""One public action catalogue for the guide and keyboard menu."""
import argparse
import curses
import json
import os
from pathlib import Path


def load(path):
    data = json.loads(Path(path).read_text())
    if data.get("version") != 1:
        raise ValueError("unsupported Fleet catalogue")
    for entries in [data["menu"], *data["media"].values()]:
        keys = [e["key"] for e in entries]
        if len(keys) != len(set(keys)):
            raise ValueError("duplicate menu key")
        for entry in entries:
            if not entry["args"] or not all(isinstance(a, str) and "\n" not in a for a in entry["args"]):
                raise ValueError("invalid action arguments")
    return data


def guide(data):
    lines = ["# Fleet: teclado y escritorio", "", "M = Command en Mac, Super en Linux. Alt = Option en Mac.",
             "Caps Lock conserva su función; AltGr conserva los símbolos.", "",
             "Las acciones de aplicaciones usan Command nativo en Mac y Super en las aplicaciones Linux compatibles.",
             "Los atajos Ctrl de Linux siguen disponibles. Una aplicación desconocida conserva sus controles.", "",
             "| Frecuencia | Acción | Atajo |", "|---|---|---|"]
    lines += [f'| {e["frequency"]} | {e["label"]} | M+{e["key"]} |' for e in data["edit"]]
    lines += ["", "VSCode: sólo el contexto correspondiente recibe cada atajo.", "", "| Acción | Atajo |", "|---|---|"]
    lines += [f'| {e["label"]} | M+{e["key"]} |' for e in data["vscode"]]
    lines += ["", "Terminal: M+C copia selección; M+V pega. Ctrl+C interrumpe, Ctrl+Z suspende y Ctrl+D conserva su función.",
              "Super+Z nunca se traduce a Ctrl+Z en una terminal. TUI y SSH conservan sus controles.", "",
              "Abre el menú con M+Alt+Enter o `fleet-menu`; suelta los modificadores antes de elegir.",
              "En Mac, una aplicación con ese atajo nativo conserva prioridad.", "", "| Tecla del menú | Acción |", "|---|---|"]
    lines += [f'| {e["key"]} | {e["label"]} |' for e in data["menu"]]
    lines += ["| Escape | Cancelar |", "", "Mover: flechas mueven; 1–9/0 envían al escritorio 1–10. Redimensionar: flechas cambian tamaño.",
              "Enter/Escape termina el modo y retira su indicador. Las demás acciones cierran el menú.", "",
              "M+Shift+3: pantalla; M+Shift+4: área; M+Shift+5: opciones de captura/grabación.",
              "Mac conserva sus capturas nativas. El menú permite archivo o portapapeles sin una cuarta tecla."]
    for name, title in [("capture", "Captura"), ("record", "Grabación")]:
        lines += ["", f"{title}:", "", "| Tecla | Acción |", "|---|---|"]
        lines += [f'| {e["key"]} | {e["label"]} |' for e in data["media"][name]]
    lines += ["", "Capturas: `~/Pictures/Screenshots`. Grabaciones: `~/Movies/ScreenRecordings`. Son archivos locales fuera de shared.",
              "Grabación: audio del equipo por defecto; micrófono sólo con `--audio microphone`. `--audio none` graba sin audio.",
              "Una sesión Fleet por usuario/equipo; `record stop` sólo detiene su propia sesión.",
              "En Mac, `record probe --region x,y,w,h` debe comprobar vídeo, audio del equipo y parada antes de habilitar grabaciones.", "",
              "```sh", "fleet-ui screenshot area --clipboard", "fleet-ui screenshot window --file auto",
              "fleet-ui screenshot screen --monitor focused --file auto", "fleet-ui record start --target area --audio system",
              "fleet-ui record start --target screen --audio system", "fleet-ui record status", "fleet-ui record stop", "```", ""]
    return "\n".join(lines)


def menu(screen, entries):
    curses.curs_set(0)
    screen.keypad(True)
    mapping = {e["key"].lower(): e["args"] for e in entries}
    arrows = {curses.KEY_LEFT: "left", curses.KEY_RIGHT: "right", curses.KEY_UP: "up", curses.KEY_DOWN: "down"}
    while True:
        screen.erase()
        height, width = screen.getmaxyx()
        rows = ["Fleet — suelta los modificadores y elige una tecla", "Escape: cancelar", ""]
        rows += [f'{e["key"]:>5}  {e["label"]}' for e in entries]
        for index, line in enumerate(rows[:max(0, height - 1)]):
            screen.addstr(index, 0, line[:max(0, width - 1)])
        screen.refresh()
        key = screen.getch()
        if key in (27, 3):
            return None
        name = arrows.get(key, chr(key).lower() if 0 <= key < 256 else "")
        if name in mapping:
            return mapping[name]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", required=True)
    sub = parser.add_subparsers(dest="command", required=True)
    doc = sub.add_parser("guide")
    doc.add_argument("--hold", action="store_true")
    pick = sub.add_parser("menu")
    pick.add_argument("--section", choices=["main", "capture", "record", "combined"], default="main")
    pick.add_argument("--selection", required=True)
    selected = sub.add_parser("selection")
    selected.add_argument("path")
    sub.add_parser("validate")
    args = parser.parse_args()
    data = load(args.catalog)
    if args.command == "guide":
        print(guide(data), end="")
        if args.hold:
            input("\nEnter para cerrar...")
    elif args.command == "menu":
        entries = data["menu"] if args.section == "main" else data["media"][args.section]
        action = curses.wrapper(menu, entries)
        # Caller creates this private file; no arbitrary command is accepted.
        fd = os.open(args.selection, os.O_WRONLY | os.O_TRUNC | os.O_NOFOLLOW)
        with os.fdopen(fd, "w") as stream:
            json.dump(action, stream)
    elif args.command == "selection":
        action = json.loads(Path(args.path).read_text())
        choices = [e["args"] for e in data["menu"]] + [e["args"] for entries in data["media"].values() for e in entries]
        if action is not None:
            if action not in choices:
                raise ValueError("selection is outside the public catalogue")
            print("\n".join(action))


if __name__ == "__main__":
    main()
