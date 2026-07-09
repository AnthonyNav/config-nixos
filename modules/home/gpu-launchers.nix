{ config, ... }:

{
  # Los .desktop originales (davinci-resolve, blender — vienen empaquetados
  # con sus respectivos derivations en home.nix) hacen `Exec=davinci-resolve`
  # / `Exec=blender %f` a secas: sin `nvidia-offload` ni el resto de fixes
  # que si tienen los lanzadores de terminal (`resolve`/`blender-gpu` en
  # zsh.nix). Rofi (y cualquier launcher tipo drun) lee esos .desktop
  # directo, así que abrir estas apps desde ahí se salta esos fixes por
  # completo — Resolve falla bajo Wayland nativo sin forzar XWayland, y
  # Blender muestra CUDA en Preferences pero "no detecta ningún dispositivo"
  # porque le falta el LD_LIBRARY_PATH hacia /run/opengl-driver/lib (mismo
  # bug documentado en CLAUDE.md, sección Troubleshooting).
  #
  # `xdg.desktopEntries` con la MISMA clave (nombre de archivo sin .desktop)
  # que el original permite *sobreescribirlo*: Home Manager lo instala con
  # prioridad alta (`lib.hiPrio`), así que gana la colisión en el perfil
  # fusionado y reemplaza solo ese archivo — el resto del paquete (binario,
  # iconos, otros .desktop como davinci-control-panels-setup) queda intacto.
  #
  # Blender usa ruta absoluta a propósito (no el `blender` de PATH): el PATH
  # de la sesión gráfica (la que usa rofi/Hyprland para lanzar .desktop) es
  # el de systemd/PAM, NO el de zsh — el `export PATH=...` que prioriza
  # ~/.local/opt/blender vive en `initContent` de zsh.nix, que solo corre en
  # shells interactivas. Sin la ruta absoluta, este .desktop resolvería
  # `blender` contra el paquete de Nix (CPU-only) otra vez, mismo bug.
  xdg.desktopEntries = {
    davinci-resolve = {
      name = "Davinci Resolve";
      genericName = "Video Editor";
      comment = "Professional video editing, color, effects and audio post-processing";
      icon = "davinci-resolve";
      terminal = false;
      categories = [ "AudioVideo" "AudioVideoEditing" "Video" "Graphics" ];
      # Mismo comando que la función `resolve` de zsh.nix.
      exec = "nvidia-offload env QT_QPA_PLATFORM=xcb davinci-resolve";
      settings.StartupWMClass = "resolve";
    };

    blender = {
      name = "Blender";
      genericName = "3D modeler";
      comment = "3D modeling, animation, rendering and post-production";
      icon = "blender";
      terminal = false;
      mimeType = [ "application/x-blender" ];
      categories = [ "Graphics" "3DGraphics" ];
      # Mismo comando que la función `blender-gpu` de zsh.nix, pero con ruta
      # absoluta al standalone (ver comentario arriba del por qué).
      exec = "nvidia-offload env LD_LIBRARY_PATH=/run/opengl-driver/lib ${config.home.homeDirectory}/.local/opt/blender/blender %f";
      settings.StartupWMClass = "Blender";
    };
  };
}
