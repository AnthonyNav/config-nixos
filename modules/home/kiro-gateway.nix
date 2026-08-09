# kiro-gateway: arranque automático (systemd --user) para el proxy que expone
# los modelos de Kiro como API OpenAI/Anthropic-compatible, consumido por
# opencode. Repo: https://github.com/Jwadow/kiro-gateway
#
# DISEÑO A PROPÓSITO DESACOPLADO DE NIX (kiro-gateway es una herramienta de
# comunidad que puede ser temporal — ver docs/maintainer.md):
#   - El código (repo clonado), el venv de Python y los SECRETOS (.env con
#     PROXY_API_KEY) viven fuera del store, en ~/dev/shared/kiro-gateway/.
#   - ~/.config/opencode/config.json (con los modelos y el provider "kiro")
#     también se edita a mano, fuera de Nix — agregar/quitar un modelo no
#     requiere rebuild.
#   - Este módulo aporta ÚNICAMENTE el unit de systemd --user que lo levanta
#     solo. Si el repo/venv no existe (o se borra), el servicio simplemente no
#     arranca (ConditionPathExists) en vez de romper `hm-switch`.
#
# Para desinstalar por completo: quita el import de este archivo en home.nix
# y borra ~/dev/shared/kiro-gateway (y opcionalmente ~/.config/opencode).
#
# Bootstrap manual (una sola vez, o para reproducir en otra máquina):
#   git clone https://github.com/Jwadow/kiro-gateway.git ~/dev/shared/kiro-gateway
#   cd ~/dev/shared/kiro-gateway && python3 -m venv .venv
#   .venv/bin/pip install -r requirements.txt
#   # .env con PROXY_API_KEY (inventado) + KIRO_CREDS_FILE=~/.aws/sso/cache/kiro-auth-token.json
#   # ver README.md, sección "Kiro Gateway + opencode", para el contenido completo.
{ ... }:

{
  systemd.user.services.kiro-gateway = {
    Unit = {
      Description = "kiro-gateway: proxy OpenAI/Anthropic-compatible para los modelos de Kiro (usado por opencode)";
      Documentation = "https://github.com/Jwadow/kiro-gateway";
      # Desacople: si el repo/venv no está clonado en esta máquina, el
      # servicio no falla el arranque de la sesión — simplemente no corre.
      ConditionPathExists = "%h/dev/shared/kiro-gateway/.venv/bin/python";
    };

    Service = {
      WorkingDirectory = "%h/dev/shared/kiro-gateway";
      # Secretos (PROXY_API_KEY, ruta a las credenciales de Kiro) fuera del
      # store, cargados en runtime desde este archivo.
      EnvironmentFile = "%h/dev/shared/kiro-gateway/.env";
      # Nota: NO se fija LD_LIBRARY_PATH aquí — nix-ld (modules/system/ai-helper.nix)
      # ya expone NIX_LD/NIX_LD_LIBRARY_PATH globalmente vía PAM, y systemd --user
      # hereda esas variables (confirmado con `systemctl --user show-environment`),
      # así que los wheels compilados del venv (tiktoken, pydantic-core, uvloop)
      # resuelven sus libs sin configuración extra.
      ExecStart = "%h/dev/shared/kiro-gateway/.venv/bin/python %h/dev/shared/kiro-gateway/main.py";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install.WantedBy = [ "default.target" ]; # arranca junto con la sesión gráfica de usuario
  };

  # Atajos de conveniencia, autocontenidos en este módulo (no tocan zsh.nix,
  # así que desaparecen solos si se quita el import).
  home.shellAliases = {
    kgw-up = "systemctl --user start kiro-gateway";
    kgw-down = "systemctl --user stop kiro-gateway";
    kgw-restart = "systemctl --user restart kiro-gateway";
    kgw-status = "systemctl --user status kiro-gateway";
    kgw-logs = "journalctl --user -u kiro-gateway -f";
  };
}
