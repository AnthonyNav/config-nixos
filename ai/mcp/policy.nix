# Explicit allowlists, independent from the catalog. Host overrides select
# their own list rather than accidentally inheriting another host's services.
{
  defaults = {
    codex = [ ];
    claude = [ ];
    kiro = [ ];
  };
  hosts = { };
}
