{ pkgs, ... }:

let
  bootstrapVersion = "v1.0.6";
  bootstrapSource = "git+https://github.com/github/spec-kit.git@${bootstrapVersion}";

  requireSpecify = ''
    if ! command -v specify >/dev/null 2>&1; then
      printf 'Spec Kit is not installed. Run speckit-bootstrap first.\n' >&2
      exit 1
    fi
  '';

  speckitBootstrap = pkgs.writeShellApplication {
    name = "speckit-bootstrap";
    runtimeInputs = [ pkgs.uv ];
    text = ''
      if command -v specify >/dev/null 2>&1; then
        specify version
        exit 0
      fi

      uv tool install specify-cli --from ${bootstrapSource}
      bin_dir="$(uv tool dir --bin)"
      "$bin_dir/specify" version
      printf 'Spec Kit installed. Open a new shell if specify is not yet visible on PATH.\n'
    '';
  };

  speckitCheck = pkgs.writeShellApplication {
    name = "speckit-check";
    text = ''
      ${requireSpecify}
      specify version
      specify self check
    '';
  };

  speckitUpdate = pkgs.writeShellApplication {
    name = "speckit-update";
    text = ''
      ${requireSpecify}
      specify self upgrade "$@"
      specify version
    '';
  };

  speckitInit = pkgs.writeShellApplication {
    name = "speckit-init";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      default_agent="''${1:-codex}"
      if (( $# > 1 )); then
        printf 'Usage: speckit-init [codex|claude|kiro-cli|opencode]\n' >&2
        exit 64
      fi

      case "$default_agent" in
        codex|claude|kiro-cli|opencode) ;;
        *)
          printf 'Unsupported default integration: %s\n' "$default_agent" >&2
          exit 64
          ;;
      esac

      ${requireSpecify}

      if [[ ! -f .specify/integration.json ]]; then
        specify init --here --force --non-interactive --integration "$default_agent"
      fi

      if ! jq -e '.installed_integrations | type == "array"' .specify/integration.json >/dev/null 2>&1; then
        printf 'Invalid or legacy Spec Kit integration state. Run: specify integration status\n' >&2
        exit 1
      fi

      for agent in codex claude kiro-cli opencode; do
        if ! jq -e --arg agent "$agent" '.installed_integrations | index($agent) != null' \
          .specify/integration.json >/dev/null; then
          # --force explicitly opts in when a combination includes an integration
          # that is not declared multi-install safe (currently OpenCode).
          specify integration install "$agent" --force
        fi
      done

      specify integration use "$default_agent"
      specify integration status
    '';
  };

  speckitSyncAgents = pkgs.writeShellApplication {
    name = "speckit-sync-agents";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      ${requireSpecify}

      if [[ ! -f .specify/integration.json ]]; then
        printf 'This directory is not initialized with Spec Kit. Run speckit-init first.\n' >&2
        exit 1
      fi

      mapfile -t integrations < <(
        jq -r '.installed_integrations[]?' .specify/integration.json
      )

      if (( ''${#integrations[@]} == 0 )); then
        printf 'No installed Spec Kit integrations were found.\n' >&2
        exit 1
      fi

      for integration in "''${integrations[@]}"; do
        specify integration upgrade "$integration"
      done

      specify integration status
    '';
  };
in
{
  home.packages = [
    speckitBootstrap
    speckitCheck
    speckitUpdate
    speckitInit
    speckitSyncAgents
  ];

  # Native non-interactive `specify init` uses this fallback when --integration
  # is omitted. Projects can still select another installed integration later.
  home.sessionVariables.SPECKIT_INTEGRATION_DEFAULT = "codex";
}
