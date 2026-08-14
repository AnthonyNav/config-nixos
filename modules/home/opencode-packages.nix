{ lib, pkgs }:

let
  managedWorkflow = pkgs.linkFarm "opencode-managed-workflow" [
    {
      name = ".gitignore";
      path = pkgs.writeText "opencode-managed-gitignore" ''
        # OpenCode requires this file, but the managed directory is immutable.
      '';
    }
    {
      name = "agents";
      path = ../../opencode/agents;
    }
    {
      name = "commands";
      path = ../../opencode/commands;
    }
    {
      name = "opencode.json";
      path = ../../opencode/opencode.json;
    }
  ];

  managedConfigHome = pkgs.linkFarm "opencode-work-config-home" [
    {
      name = "opencode";
      path = managedWorkflow;
    }
  ];

  managedTreeState = pkgs.writeShellApplication {
    name = "opencode-work-tree-state";
    runtimeInputs = [
      pkgs.git
      pkgs.python3
    ];
    text = ''
      exec python3 - <<'PY'
      import hashlib
      import json
      import os
      import stat
      import subprocess

      root = subprocess.check_output(
          ["git", "rev-parse", "--show-toplevel"], text=True
      ).strip()
      symlinks = []

      for current, directories, files in os.walk(root, followlinks=False):
          if current == os.path.join(root, ".git"):
              directories.clear()
              continue
          directories[:] = [name for name in directories if name != ".git"]
          for name in list(directories) + files:
              path = os.path.join(current, name)
              if stat.S_ISLNK(os.lstat(path).st_mode):
                  symlinks.append(os.path.relpath(path, root))
          directories[:] = [
              name
              for name in directories
              if not os.path.islink(os.path.join(current, name))
          ]

      ignored_raw = subprocess.check_output(
          ["git", "ls-files", "--others", "--ignored", "--exclude-standard", "-z"]
      )
      ignored = [path for path in ignored_raw.decode().split("\0") if path]
      digest = hashlib.sha256()
      total_bytes = 0
      supported = len(ignored) <= 5000

      for relative in sorted(ignored):
          path = os.path.join(root, relative)
          if os.path.islink(path):
              continue
          if not os.path.isfile(path):
              supported = False
              continue
          size = os.path.getsize(path)
          total_bytes += size
          if total_bytes > 100 * 1024 * 1024:
              supported = False
              break
          digest.update(relative.encode())
          digest.update(b"\0")
          with open(path, "rb") as stream:
              for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                  digest.update(chunk)
          digest.update(b"\0")

      print(json.dumps({
          "ignored_count": len(ignored),
          "ignored_sha256": digest.hexdigest() if supported else None,
          "ignored_supported": supported,
          "symlinks": sorted(symlinks),
      }, separators=(",", ":")))
      PY
    '';
  };

  managedPrepareNewFiles = pkgs.writeShellApplication {
    name = "opencode-work-prepare-new-files";
    runtimeInputs = [ pkgs.git ];
    text = ''
      mapfile -d "" files < <(git ls-files --others --exclude-standard -z)
      if (( "''${#files[@]}" > 0 )); then
        git add -N -- "''${files[@]}"
      fi
    '';
  };

  managedNixFormatter = pkgs.writeShellApplication {
    name = "opencode-work-format-nix";
    runtimeInputs = [
      pkgs.git
      pkgs.nixfmt
    ];
    text = ''
      mapfile -d "" files < <(
        git diff --name-only --diff-filter=ACMR -z --no-ext-diff --no-textconv HEAD -- '*.nix'
      )
      if (( "''${#files[@]}" > 0 )); then
        nixfmt "''${files[@]}"
      fi
    '';
  };

  mkOpenCode =
    {
      name,
      managed ? false,
    }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        pkgs.coreutils
        pkgs.opencode
        pkgs.python3
      ]
      ++ lib.optionals managed [
        managedNixFormatter
        managedPrepareNewFiles
        managedTreeState
      ];
      text = ''
        base_data_home="''${XDG_DATA_HOME:-$HOME/.local/share}"
        base_state_home="''${XDG_STATE_HOME:-$HOME/.local/state}"
        gateway_env="''${XDG_CONFIG_HOME:-$HOME/.config}/kiro-gateway/.env"
        data_dir="$base_data_home/kiro-gateway"
        catalog="$base_state_home/opencode/kiro-models.json"

        ${lib.optionalString managed ''
          # Isolate /work from project config and caller-supplied late overrides.
          unset OPENCODE_CONFIG
          unset OPENCODE_PERMISSION
          unset OPENCODE_TUI_CONFIG
          export OPENCODE_DISABLE_CLAUDE_CODE=1
          export OPENCODE_DISABLE_PROJECT_CONFIG=1
          export OPENCODE_PURE=1
          export OPENCODE_CONFIG_DIR=${managedWorkflow}
          export OPENCODE_CONFIG_CONTENT='{"formatter":false,"lsp":false,"permission":{"*":"deny"}}'
          export XDG_CONFIG_HOME=${managedConfigHome}
          workflow_data_home="$base_data_home/opencode-work"
          rm -rf "$workflow_data_home/opencode/tool-output"
          export XDG_DATA_HOME="$workflow_data_home"
          export XDG_CACHE_HOME="''${XDG_CACHE_HOME:-$HOME/.cache}/opencode-work"
          export XDG_STATE_HOME="$base_state_home/opencode-work"
          export GIT_CONFIG_GLOBAL=/dev/null
          export GIT_CONFIG_NOSYSTEM=1
          export GIT_CONFIG_COUNT=2
          export GIT_CONFIG_KEY_0=core.fsmonitor
          export GIT_CONFIG_VALUE_0=false
          export GIT_CONFIG_KEY_1=core.hooksPath
          export GIT_CONFIG_VALUE_1=/dev/null
          export GIT_PAGER=cat
        ''}

        # Kiro is loaded only after a successful bootstrap. Do not execute .env as shell code.
        if [[ -f "$data_dir/configured" && -r "$gateway_env" && -r "$catalog" ]]; then
          proxy_api_key="$(python3 - "$gateway_env" <<'PY'
        import re
        import sys

        for line in open(sys.argv[1], encoding="utf-8"):
            match = re.fullmatch(r"\s*PROXY_API_KEY\s*=\s*(.*?)\s*", line)
            if not match:
                continue
            value = match.group(1)
            if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
                value = value[1:-1]
            print(value, end="")
            break
        PY
          )"
          if [[ -n "$proxy_api_key" ]]; then
            export PROXY_API_KEY="$proxy_api_key"
            ${lib.optionalString (!managed) ''export OPENCODE_CONFIG="$catalog"''}
          fi
        fi

        exec ${lib.getExe pkgs.opencode} "$@"
      '';
    };
in
{
  inherit
    managedNixFormatter
    managedPrepareNewFiles
    managedTreeState
    managedWorkflow
    ;
  default = mkOpenCode { name = "opencode"; };
  workflow = mkOpenCode {
    name = "opencode-work";
    managed = true;
  };
}
