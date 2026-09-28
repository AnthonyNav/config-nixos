{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.fleet.development.legacyJupyterLibraries = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Keep global native libraries until existing data projects pass inside their own devShells.";
  };

  config.programs.zsh.initContent = lib.mkIf config.fleet.development.legacyJupyterLibraries (
    lib.mkAfter ''
      # Bibliotecas nativas para los kernels de Jupyter iniciados desde este shell.
      # Usar el nixpkgs fijado evita consultas de red al abrir cada terminal.
      FIRA_CC_LIB="${pkgs.stdenv.cc.cc.lib}"
      FIRA_ZLIB="${pkgs.zlib}"
      FIRA_EXPAT="${pkgs.expat}"
      case ":''${LD_LIBRARY_PATH-}:" in
        *":$FIRA_CC_LIB/lib:$FIRA_ZLIB/lib:$FIRA_EXPAT/lib:"*) ;;
        *) export LD_LIBRARY_PATH="$FIRA_CC_LIB/lib:$FIRA_ZLIB/lib:$FIRA_EXPAT/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ;;
      esac

    ''
  );
}
