{
  lib,
  pkgsFor,
  self,
  username,
  workstationNames,
  fleetNames,
  inputSharingHostNames,
  workstations,
  fleetEndpoints,
  tailnetPolicy,
  tailscalePolicyConfig,
  tailscalePolicyPrinter,
  treefmtEval,
  aiToolsPackages,
  aiToolVersions,
  nixConfigPackages,
}:
{
  monitor-layout =
    pkgsFor.runCommand "monitor-layout-check"
      {
        nativeBuildInputs = [ pkgsFor.python3 ];
      }
      ''
        python ${../scripts/tests/check-monitor-layout.py} ${../scripts/monitor-layout.py} ${pkgsFor.writeText "monitor-policy.json" (builtins.toJSON (import ../inventory/displays.nix))}
        touch "$out"
      '';
  manual-monitors =
    pkgsFor.runCommand "manual-monitors-check"
      {
        nativeBuildInputs = [
          pkgsFor.bash
          pkgsFor.python3
          pkgsFor.jq
          pkgsFor.gawk
          pkgsFor.shellcheck
        ];
      }
      ''
        shellcheck ${../scripts/set-monitor.sh}
        python ${../scripts/tests/check-set-monitor.py} ${../scripts/set-monitor.sh}
        touch "$out"
      '';
  dotfiles =
    let
      settings =
        self.homeConfigurations."${username}@${builtins.head workstationNames}".config.programs.starship.settings;
    in
    assert settings == builtins.fromTOML (builtins.readFile ../dotfiles/starship/starship.toml);
    pkgsFor.runCommand "dotfiles-check"
      {
        nativeBuildInputs = [ pkgsFor.neovim-unwrapped ];
      }
      ''
        export XDG_CONFIG_HOME="$TMPDIR/config"
        export XDG_DATA_HOME="$TMPDIR/data"
        export XDG_STATE_HOME="$TMPDIR/state"
        export XDG_CACHE_HOME="$TMPDIR/cache"
        nvim --headless -i NONE -u ${../dotfiles/neovim/options.lua} \
          "+lua if not (vim.o.number and vim.o.relativenumber and vim.o.expandtab and vim.o.tabstop == 2 and vim.o.shiftwidth == 2 and vim.o.undofile) then vim.cmd('cquit 1') end" \
          +qa
        touch "$out"
      '';
  development-path = pkgsFor.runCommand "development-path-check" { } ''
    mkdir -p "$TMPDIR"/{managed,project,home/.local/bin,home/.local/share/pnpm,home/.npm-global/bin}
    touch "$TMPDIR/managed/codex" "$TMPDIR/project/codex" \
      "$TMPDIR/home/.npm-global/bin/codex" "$TMPDIR/home/.local/bin/local-only"
    chmod +x "$TMPDIR/managed/codex" "$TMPDIR/project/codex" \
      "$TMPDIR/home/.npm-global/bin/codex" "$TMPDIR/home/.local/bin/local-only"
    HOME="$TMPDIR/home" TEST_ROOT="$TMPDIR" ${pkgsFor.zsh}/bin/zsh -f ${pkgsFor.writeText "development-path-test.zsh" ''
      set -eu
      path=("$HOME/.npm-global/bin" "$HOME/.local/bin" "$TEST_ROOT/project" "$TEST_ROOT/managed")
      source ${../scripts/development-path.zsh}
      [[ "$(whence -p codex)" == "$TEST_ROOT/project/codex" ]]
      path=("''${(@)path:#$TEST_ROOT/project}")
      source ${../scripts/development-path.zsh}
      [[ "$(whence -p codex)" == "$TEST_ROOT/managed/codex" ]]
      [[ "$(whence -p local-only)" == "$HOME/.local/bin/local-only" ]]
      previous_path=$PATH
      source ${../scripts/development-path.zsh}
      [[ "$PATH" == "$previous_path" ]]
    ''}
    touch "$out"
  '';
  resource-policy =
    let
      configs = lib.mapAttrs (_: host: host.config) (
        lib.getAttrs workstationNames self.nixosConfigurations
      );
      inherit (configs) victus;
      inherit (configs) desktop;
      desktopHome = self.homeConfigurations."${username}@desktop".config;
      victusFallbackSwap = builtins.filter (
        swap: swap.device == "/var/lib/nixos-victus-memory-swapfile"
      ) victus.swapDevices;
    in
    assert lib.all (c: c.nix.settings.cores > 0 && c.nix.settings."max-jobs" > 0) (
      builtins.attrValues configs
    );
    assert desktop.nix.settings."max-jobs" == 2;
    assert desktop.nix.settings.cores == 2;
    assert builtins.length victusFallbackSwap == 1;
    assert (builtins.head victusFallbackSwap).randomEncryption.enable;
    assert (builtins.head victusFallbackSwap).priority < victus.zramSwap.priority;
    assert !victus.systemd.sleep.settings.Sleep.AllowHibernation;
    assert !victus.systemd.sleep.settings.Sleep.AllowHybridSleep;
    assert !victus.systemd.sleep.settings.Sleep.AllowSuspendThenHibernate;
    assert desktop.systemd.sleep.settings.Sleep.AllowSuspend;
    assert !desktop.systemd.sleep.settings.Sleep.AllowHibernation;
    assert !desktop.systemd.sleep.settings.Sleep.AllowHybridSleep;
    assert !desktop.systemd.sleep.settings.Sleep.AllowSuspendThenHibernate;
    assert desktopHome.estoma.idle.suspendTimeoutSeconds == null;
    assert
      self.homeConfigurations."${username}@victus".config.estoma.idle.suspendTimeoutSeconds == 1800;
    assert
      !(lib.any (
        l: (l.on-timeout or "") == "systemctl suspend"
      ) desktopHome.services.hypridle.settings.listener);
    assert lib.all (
      c:
      c.virtualisation.docker.enable
      && !c.virtualisation.docker.enableOnBoot
      && !(builtins.elem "multi-user.target" c.systemd.services.docker.wantedBy)
      && builtins.elem "sockets.target" c.systemd.sockets.docker.wantedBy
    ) (builtins.attrValues configs);
    assert victus.hardware.nvidia-container-toolkit.enable;
    assert desktop.hardware.nvidia-container-toolkit.enable;
    assert !desktop.services.k3s.enable;
    assert (desktop.networking.firewall.interfaces.docker0.allowedTCPPorts or [ ]) == [ ];
    assert (desktop.networking.firewall.interfaces.docker0.allowedTCPPortRanges or [ ]) == [ ];
    pkgsFor.runCommand "resource-policy-check" { } ''
      touch "$out"
    '';
  ai-tools =
    pkgsFor.runCommand "ai-tools-check"
      {
        nativeBuildInputs = [
          aiToolsPackages.claude-code
          aiToolsPackages.codex
          aiToolsPackages.opencode
          aiToolsPackages.rtk
        ];
      }
      ''
        export HOME="$TMPDIR/home"
        export XDG_CACHE_HOME="$TMPDIR/cache"
        export XDG_CONFIG_HOME="$TMPDIR/config"
        export XDG_DATA_HOME="$TMPDIR/data"
        export XDG_STATE_HOME="$TMPDIR/state"
        mkdir -p "$HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"

        claude --version | grep -F ${lib.escapeShellArg aiToolVersions.claudeCode}
        codex --version | grep -F ${lib.escapeShellArg aiToolVersions.codex}
        codex features list | grep -E '^daemon_auto_start +[a-z]+ +false$'
        opencode --version | grep -F ${lib.escapeShellArg aiToolVersions.opencode}
        rtk --version | grep -F ${lib.escapeShellArg aiToolVersions.rtk}
        touch "$out"
      '';
  formatting = treefmtEval.config.build.check self;
  fleet-interaction =
    pkgsFor.runCommand "fleet-interaction-check"
      {
        nativeBuildInputs = [
          pkgsFor.bash
          pkgsFor.shellcheck
        ];
      }
      ''
        shellcheck \
          ${../scripts/fleet-ui.sh} \
          ${../scripts/fleet-ui-linux.sh} \
          ${../scripts/fleet-ui-darwin.sh} \
          ${../scripts/fleet-menu.sh} \
          ${../scripts/fleet-shortcuts.sh}
        bash ${../scripts/fleet-ui-linux.sh} --help >/dev/null
        bash ${../scripts/fleet-ui-darwin.sh} --help >/dev/null
        ! grep -Eiq 'darwin|linux|hyprland|aerospace' ${../scripts/fleet-ui.sh}
        touch "$out"
      '';
  ci-workflows =
    pkgsFor.runCommand "ci-workflows-check"
      {
        nativeBuildInputs = [ pkgsFor.actionlint ];
      }
      ''
        actionlint \
          ${../.github/workflows/flake-check.yml} \
          ${../.github/workflows/full-build.yml}
        touch "$out"
      '';
  network-endpoints =
    let
      allEndpoints = fleetEndpoints.tailnet ++ fleetEndpoints.public;
      endpointHosts = lib.concatMap (endpoint: endpoint.hosts) allEndpoints;
      endpointBindings = lib.concatMap (
        endpoint: map (host: "${host}:${endpoint.protocol}:${toString endpoint.port}") endpoint.hosts
      ) allEndpoints;
      tailnetGrantBindings = map (
        endpoint: "${endpoint.protocol}:${toString endpoint.port}"
      ) fleetEndpoints.tailnet;
      expectedInputPeers =
        host: lib.sort builtins.lessThan (builtins.filter (name: name != host) inputSharingHostNames);
      declaredInputPeers =
        host:
        lib.sort builtins.lessThan (map (peer: peer.host) workstations.${host}.features.inputSharing.peers);
      validPort = endpoint: endpoint.port > 0 && endpoint.port <= 65535;
      orcaEnabled = lib.any (
        name: (workstations.${name}.features.orcaRemote.mode or "off") != "off"
      ) workstationNames;
    in
    assert lib.all (host: builtins.elem host fleetNames) endpointHosts;
    assert lib.all validPort allEndpoints;
    assert builtins.length endpointBindings == builtins.length (lib.unique endpointBindings);
    assert builtins.length tailnetGrantBindings == builtins.length (lib.unique tailnetGrantBindings);
    assert lib.all (host: declaredInputPeers host == expectedInputPeers host) inputSharingHostNames;
    assert fleetEndpoints.public == [ ];
    assert
      lib.sort builtins.lessThan tailnetGrantBindings == lib.sort builtins.lessThan (
        [
          "tcp:22"
          "tcp:22000"
          "udp:4242"
        ]
        ++ lib.optional orcaEnabled "tcp:${toString fleetEndpoints.ports.orca}"
      );
    pkgsFor.runCommand "network-endpoints-check" { } ''
      touch "$out"
    '';
  identity-policy =
    let
      homeConfig = self.homeConfigurations."${username}@${builtins.head workstationNames}".config;
      gitSettings = homeConfig.programs.git.settings;
      sshSettings = homeConfig.programs.ssh.settings;
      identityPolicy = import ../inventory/identities.nix;
      retainsScript =
        filename: command:
        lib.any (path: lib.hasInfix "${path}/${filename}" command) (
          builtins.attrNames (builtins.getContext command)
        );
      includesRetainScripts = lib.all (
        include:
        retainsScript "workspace-context.py" include.contents.core.sshCommand
        && retainsScript "workspace-context.py" (
          builtins.elemAt include.contents.credential."https://github.com".helper 1
        )
      ) homeConfig.programs.git.includes;
      orcaHelpers = lib.filter (
        package: lib.hasPrefix "orca-server-" package.name
      ) homeConfig.home.packages;
      syncthingHelpers =
        lib.filter (package: package.name == "syncthing-fleet-reconcile")
          self.nixosConfigurations.${builtins.head workstationNames}.config.users.users.${username}.packages;
    in
    assert identityPolicy.default == "neutral";
    assert gitSettings.user.useConfigOnly;
    assert !(gitSettings.user ? email) && !(gitSettings.user ? name);
    assert !(builtins.hasAttr "git@github.com:" (gitSettings.url or { }));
    assert sshSettings."github.com".data.IdentityFile == "none";
    assert sshSettings."github.com".data.IdentityAgent == "none";
    assert sshSettings."github.com-personal".data.IdentityFile == "/home/${username}/.ssh/id_personal";
    assert sshSettings."github.com-work".data.IdentityFile == "/home/${username}/.ssh/id_work";
    assert sshSettings."github.com-kigo".data.IdentityFile == "/home/${username}/.ssh/id_work";
    assert builtins.elem "projects/" identityPolicy.identities.personal.roots;
    assert builtins.elem "nixos-config/" identityPolicy.identities.personal.roots;
    assert identityPolicy.identities.work.aws.profile == "work-readonly";
    assert identityPolicy.identities.personal.aws.profile == "personal-readonly";
    # Embedded commands must retain their script as a store dependency after GC.
    assert includesRetainScripts;
    assert lib.all (package: retainsScript "orca-server.py" package.text) orcaHelpers;
    assert lib.all (package: retainsScript "syncthing-ignores.py" package.text) syncthingHelpers;
    pkgsFor.runCommand "identity-policy-check" { } ''
      touch "$out"
    '';
  tailscale-policy =
    let
      host = builtins.head workstationNames;
      systemConfig = self.nixosConfigurations.${host}.config;
      homeConfig = self.homeConfigurations."${username}@${host}".config;
      tailscaleConfig = systemConfig.services.tailscale;
      tailscaleFirewall = systemConfig.networking.firewall.interfaces.tailscale0;
      fleetSshSettings = homeConfig.programs.ssh.settings;
      grant = builtins.head tailnetPolicy.grants;
      sshRule = builtins.head tailnetPolicy.ssh;
      expectedGrantIps = builtins.map (
        endpoint: "${endpoint.protocol}:${toString endpoint.port}"
      ) fleetEndpoints.tailnet;
      expectedProxyCommand = "${lib.getExe pkgsFor.tailscale} nc %h %p";
    in
    assert tailscaleConfig.enable;
    assert tailscalePolicyConfig.node.allowIncoming;
    assert
      tailscaleConfig.extraSetFlags == [
        "--hostname=${host}"
        "--shields-up=false"
        "--ssh"
      ];
    assert systemConfig.services.openssh.enable;
    assert builtins.elem fleetEndpoints.ports.ssh tailscaleFirewall.allowedTCPPorts;
    assert grant.src == [ "autogroup:member" ];
    assert grant.dst == [ "autogroup:self" ];
    assert grant.ip == expectedGrantIps;
    assert !(builtins.elem "*" grant.ip);
    assert sshRule.action == "check";
    assert sshRule.src == [ "autogroup:member" ];
    assert sshRule.dst == [ "autogroup:self" ];
    assert sshRule.users == [ username ];
    assert sshRule.checkPeriod == "12h";
    assert lib.all (
      name:
      fleetSshSettings.${name}.data.User == username
      && fleetSshSettings.${name}.data.ProxyCommand == expectedProxyCommand
    ) workstationNames;
    assert !(fleetSshSettings ? thinkpad) && !(fleetSshSettings ? debian-server);
    assert fleetSshSettings.desktop.data.ProxyCommand == expectedProxyCommand;
    assert fleetSshSettings.victus.data.ProxyCommand == expectedProxyCommand;
    pkgsFor.runCommand "tailscale-policy-check" { } ''
      ${lib.getExe tailscalePolicyPrinter} >/dev/null
      touch "$out"
    '';
  syncthing-policy =
    let
      systemConfig = self.nixosConfigurations.${builtins.head workstationNames}.config;
      syncthingConfig = systemConfig.services.syncthing;
      tailscaleFirewall = systemConfig.networking.firewall.interfaces.tailscale0;
      syncthingPolicy = import ../inventory/syncthing.nix;
    in
    assert syncthingConfig.enable;
    assert !syncthingConfig.overrideDevices;
    assert !syncthingConfig.overrideFolders;
    assert
      syncthingConfig.settings.options.listenAddresses == [
        "tcp://0.0.0.0:${toString fleetEndpoints.ports.syncthing}"
      ];
    assert !syncthingConfig.settings.options.globalAnnounceEnabled;
    assert !syncthingConfig.settings.options.localAnnounceEnabled;
    assert !syncthingConfig.settings.options.relaysEnabled;
    assert !syncthingConfig.settings.options.natEnabled;
    assert builtins.elem fleetEndpoints.ports.syncthing tailscaleFirewall.allowedTCPPorts;
    assert !(builtins.elem fleetEndpoints.ports.syncthing (tailscaleFirewall.allowedUDPPorts or [ ]));
    assert !(builtins.elem 21027 (tailscaleFirewall.allowedUDPPorts or [ ]));
    assert
      builtins.attrNames syncthingPolicy.folders == [
        "personal"
        "work"
      ];
    assert syncthingPolicy.folders.work.id == "fleet-work";
    assert syncthingPolicy.folders.personal.id == "fleet-personal";
    assert syncthingPolicy.folders.work.relativePath == "Workspace/work";
    assert syncthingPolicy.folders.personal.relativePath == "Workspace/personal";
    pkgsFor.runCommand "syncthing-policy-check" { } ''
      touch "$out"
    '';
  nvidia-suspend =
    let
      configs = map (name: self.nixosConfigurations.${name}.config) workstationNames;
      suspendingNvidia = builtins.filter (
        c:
        builtins.elem "nvidia" c.services.xserver.videoDrivers
        && (c.systemd.sleep.settings.Sleep.AllowSuspend or true)
      ) configs;
      preservesVram =
        c:
        let
          nvidia = c.hardware.nvidia;
          suspend = c.systemd.services.nvidia-suspend or { };
          resume = c.systemd.services.nvidia-resume or { };
        in
        nvidia.powerManagement.enable
        && (nvidia.moduleParams.nvidia.NVreg_PreserveVideoMemoryAllocations or 0) == 1
        && (
          if nvidia.powerManagement.kernelSuspendNotifier then
            (nvidia.moduleParams.nvidia.NVreg_UseKernelSuspendNotifiers or 0) == 1
          else
            (suspend.enable or false)
            && (resume.enable or false)
            && builtins.elem "systemd-suspend.service" (suspend.before or [ ])
            && builtins.elem "systemd-suspend.service" (suspend.requiredBy or [ ])
            && builtins.elem "systemd-suspend.service" (resume.after or [ ])
            && builtins.elem "systemd-suspend.service" (resume.requiredBy or [ ])
        );
    in
    assert lib.assertMsg (lib.all preservesVram suspendingNvidia)
      "Suspending NVIDIA workstations must preserve VRAM with an ordered suspend/resume integration.";
    pkgsFor.runCommand "nvidia-suspend-check" { } ''touch "$out"'';
  workstation-policy =
    let
      systemConfigs = map (name: self.nixosConfigurations.${name}.config) workstationNames;
      homeConfigs = map (name: self.homeConfigurations."${username}@${name}".config) workstationNames;
    in
    assert self.nixosConfigurations.desktop.config.users.users.${username}.linger;
    assert !self.nixosConfigurations.victus.config.users.users.${username}.linger;
    assert lib.all (
      c:
      !c.services.k3s.enable
      && !(builtins.hasAttr "woodpecker-agent-desktop" c.systemd.services)
      && !(builtins.hasAttr "woodpecker-agent-victus" c.systemd.services)
      && !(builtins.hasAttr "remote-workspace-serve" c.systemd.services)
      && !(builtins.elem 8082 c.networking.firewall.allowedTCPPorts)
      && !(builtins.elem 8082 c.networking.firewall.interfaces.tailscale0.allowedTCPPorts)
      && !(builtins.elem 8448 c.networking.firewall.interfaces.tailscale0.allowedTCPPorts)
    ) systemConfigs;
    assert lib.all (c: !(builtins.hasAttr "remote-workspace" c.systemd.user.services)) homeConfigs;
    assert aiToolsPackages ? codex;
    pkgsFor.runCommand "workstation-policy-check" { } ''
      touch "$out"
    '';
  nix-config =
    pkgsFor.runCommand "nix-config-check"
      {
        nativeBuildInputs = [
          pkgsFor.bash
          pkgsFor.coreutils
          pkgsFor.git
          pkgsFor.gnused
          pkgsFor.jq
          pkgsFor.shellcheck
          pkgsFor.util-linux
          nixConfigPackages.nixConfig
        ];
      }
      ''
        shellcheck \
          ${../scripts/nix-config.sh} \
          ${../scripts/tests/check-nix-config.sh} \
          ${../scripts/macos-readiness.sh} \
          ${../scripts/tests/check-macos-readiness.sh} \
          ${../scripts/tests/check-input-share.sh} \
          ${../scripts/input-share-reconcile.sh} \
          ${../scripts/syncthing-fleet-reconcile.sh}
        bash ${../scripts/tests/check-nix-config.sh} ${../scripts/nix-config.sh}
        bash ${../scripts/tests/check-macos-readiness.sh} ${../scripts/macos-readiness.sh}
        bash ${../scripts/tests/check-input-share.sh} ${../scripts/input-share-reconcile.sh}
        nix-config --help >/dev/null
        touch "$out"
      '';
}
