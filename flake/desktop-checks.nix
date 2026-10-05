{
  lib,
  pkgs,
  self,
  username,
  workstationNames,
}:
let
  home = self.homeConfigurations."${username}@${builtins.head workstationNames}".config;
  templates = pkgs.linkFarm "desktop-theme-templates" (
    map
      (name: {
        inherit name;
        path = pkgs.writeText name home.xdg.configFile."caelestia/templates/${name}".text;
      })
      [
        "kitty-colors.conf"
        "rofi.rasi"
        "hyprland-colors.conf"
        "starship.toml"
      ]
  );
  policy = pkgs.writeText "appearance-policy.json" (
    builtins.toJSON (import ../modules/home/caelestia-personalization-policy.nix { inherit lib; })
  );
  configs = map (name: self.nixosConfigurations.${name}.config) workstationNames;
  backupFixture = self.nixosConfigurations.desktop.extendModules {
    modules = [
      {
        fleet.backup = {
          enable = true;
          paths = [ "/home/${username}/Documents" ];
        };
      }
    ];
  };
  rootlessFixture = self.nixosConfigurations.victus.extendModules {
    modules = [ { fleet.containers.rootless = true; } ];
  };
  rootless = rootlessFixture.config;
in
{
  syncthing-reconcile =
    pkgs.runCommand "syncthing-reconcile-check"
      {
        nativeBuildInputs = [
          pkgs.bash
          pkgs.python3
          pkgs.jq
          pkgs.openssl
          pkgs.coreutils
          pkgs.gawk
          pkgs.shellcheck
        ];
      }
      ''
        shellcheck ${../scripts/syncthing-fleet-reconcile.sh}
        python ${../scripts/tests/check-syncthing.py} ${../scripts}/syncthing-fleet-reconcile.sh
        touch "$out"
      '';
  desktop-appearance =
    pkgs.runCommand "desktop-appearance-check"
      {
        nativeBuildInputs = [
          pkgs.python3
          pkgs.starship
          pkgs.shellcheck
        ];
      }
      ''
        python ${../scripts/tests/check-desktop-appearance.py} ${../scripts/desktop-appearance.py} ${policy} ${templates} ${home.programs.caelestia.cli.package}/bin/caelestia
        shellcheck ${../scripts/workstation-doctor.sh}
        export STARSHIP_CACHE="$TMPDIR/cache/starship"
        mkdir -p "$STARSHIP_CACHE"
        mkdir -p "$TMPDIR/config"
        ${pkgs.python3}/bin/python - ${policy} ${templates}/starship.toml "$TMPDIR/config" ${../scripts/desktop-appearance.py} <<'PY'
        import importlib.util, json, pathlib, sys
        spec = importlib.util.spec_from_file_location("appearance", sys.argv[4])
        appearance = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(appearance)
        policy = json.loads(pathlib.Path(sys.argv[1]).read_text())
        for mode, colours in policy["colours"].items():
            pathlib.Path(sys.argv[3], mode + ".toml").write_bytes(appearance.render(pathlib.Path(sys.argv[2]).read_text(), colours))
        PY
        for mode in dark light; do
          STARSHIP_CONFIG="$TMPDIR/config/$mode.toml" starship print-config >/dev/null
        done
        touch "$out"
      '';
  caelestia-launchers =
    pkgs.runCommand "caelestia-launchers-check" { nativeBuildInputs = [ pkgs.nodejs_22 ]; }
      ''
        node ${../scripts/test-caelestia-app-scopes.mjs} \
          ${home.programs.caelestia.package}/share/caelestia-shell/modules/launcher/services/Apps.qml \
          ${home.programs.caelestia.package}/share/caelestia-shell/modules/launcher/services/Actions.qml
        touch "$out"
      '';
  backup-restore = pkgs.runCommand "backup-restore-check" { nativeBuildInputs = [ pkgs.restic ]; } ''
    export RESTIC_REPOSITORY="$TMPDIR/repository"
    export RESTIC_PASSWORD_FILE="$TMPDIR/password"
    export XDG_CACHE_HOME="$TMPDIR/cache"
    printf 'fixture-only-password\n' > "$RESTIC_PASSWORD_FILE"
    chmod 600 "$RESTIC_PASSWORD_FILE"
    mkdir -p "$TMPDIR/data" "$TMPDIR/restore"
    printf 'restore acceptance fixture\n' > "$TMPDIR/data/document.txt"
    restic init
    restic backup "$TMPDIR/data"
    printf 'modified after backup\n' > "$TMPDIR/data/document.txt"
    restic check --read-data
    restic restore latest --target "$TMPDIR/restore"
    printf 'restore acceptance fixture\n' > "$TMPDIR/expected"
    cmp "$TMPDIR/expected" "$TMPDIR/restore/$TMPDIR/data/document.txt"
    touch "$out"
  '';
  blender-standalone = pkgs.runCommand "blender-standalone-check" { } ''
    export XDG_CONFIG_HOME="$TMPDIR/config"
    export XDG_CACHE_HOME="$TMPDIR/cache"
    ${self.packages.${pkgs.stdenv.hostPlatform.system}.blender-standalone}/bin/blender \
      --background --factory-startup --python-exit-code 1 \
      --python-expr 'import bpy; assert bpy.app.build_options.cycles'
    touch "$out"
  '';
  recovery-policy =
    assert lib.all (c: !c.fleet.backup.enable && c.services.restic.backups == { }) configs;
    assert backupFixture.config.services.restic.backups.fleet-personal.createWrapper;
    assert !backupFixture.config.services.restic.backups.fleet-personal.initialize;
    assert
      backupFixture.config.services.restic.backups.fleet-integrity.checkOpts
      == [ "--read-data-subset=5%" ];
    assert !rootless.virtualisation.docker.enable && rootless.virtualisation.docker.rootless.enable;
    assert rootless.virtualisation.docker.rootless.setSocketVariable;
    assert !(builtins.elem "docker" rootless.users.users.${username}.extraGroups);
    assert rootless.systemd.user.services.docker.wantedBy == [ ];
    assert lib.all (
      c:
      c.networking.firewall.enable
      && c.networking.firewall.allowedTCPPorts == [ ]
      && c.networking.firewall.allowedUDPPorts == [ ]
      && c.services.openssh.settings.PermitRootLogin == "no"
      && !c.services.openssh.settings.PasswordAuthentication
      && !c.services.openssh.settings.KbdInteractiveAuthentication
      && !c.services.openssh.openFirewall
      && c.services.syncthing.guiAddress == "127.0.0.1:8384"
    ) configs;
    pkgs.runCommand "recovery-policy-check" { } ''touch "$out"'';
}
