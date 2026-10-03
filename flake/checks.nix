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
      thinkpad = configs.thinkpad;
      victus = configs.victus;
      desktop = configs.desktop;
      desktopHome = self.homeConfigurations."${username}@desktop".config;
      thinkpadFallbackSwap = builtins.filter (
        swap: swap.device == "/var/lib/nixos-memory-swapfile"
      ) thinkpad.swapDevices;
      victusFallbackSwap = builtins.filter (
        swap: swap.device == "/var/lib/nixos-victus-memory-swapfile"
      ) victus.swapDevices;
    in
    assert lib.all (c: c.nix.settings.cores > 0 && c.nix.settings."max-jobs" > 0) (
      builtins.attrValues configs
    );
    assert thinkpad.nix.settings."max-jobs" <= desktop.nix.settings."max-jobs";
    assert desktop.nix.settings."max-jobs" == 2;
    assert desktop.nix.settings.cores == 2;
    assert builtins.length thinkpadFallbackSwap == 1;
    assert (builtins.head thinkpadFallbackSwap).randomEncryption.enable;
    assert (builtins.head thinkpadFallbackSwap).priority < thinkpad.zramSwap.priority;
    assert builtins.length victusFallbackSwap == 1;
    assert (builtins.head victusFallbackSwap).randomEncryption.enable;
    assert (builtins.head victusFallbackSwap).priority < victus.zramSwap.priority;
    assert !thinkpad.systemd.sleep.settings.Sleep.AllowHibernation;
    assert !thinkpad.systemd.sleep.settings.Sleep.AllowHybridSleep;
    assert !thinkpad.systemd.sleep.settings.Sleep.AllowSuspendThenHibernate;
    assert !victus.systemd.sleep.settings.Sleep.AllowHibernation;
    assert !victus.systemd.sleep.settings.Sleep.AllowHybridSleep;
    assert !victus.systemd.sleep.settings.Sleep.AllowSuspendThenHibernate;
    assert desktop.systemd.sleep.settings.Sleep.AllowSuspend;
    assert !desktop.systemd.sleep.settings.Sleep.AllowHibernation;
    assert !desktop.systemd.sleep.settings.Sleep.AllowHybridSleep;
    assert !desktop.systemd.sleep.settings.Sleep.AllowSuspendThenHibernate;
    assert desktopHome.estoma.idle.suspendTimeoutSeconds == 1800;
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
    assert desktop.fleet.lab.ci.agents == { };
    assert !desktop.fleet.lab.publication.woodpecker.enable;
    assert desktop.fleet.lab.publication.privateUis == { };
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
      expectedRemoteWorkspaceHosts = builtins.filter (
        name: workstations.${name}.features.remoteWorkspace.enable
      ) workstationNames;
      validPort = endpoint: endpoint.port > 0 && endpoint.port <= 65535;
    in
    assert lib.all (host: builtins.elem host fleetNames) endpointHosts;
    assert lib.all validPort allEndpoints;
    assert builtins.length endpointBindings == builtins.length (lib.unique endpointBindings);
    assert builtins.length tailnetGrantBindings == builtins.length (lib.unique tailnetGrantBindings);
    assert lib.all (host: declaredInputPeers host == expectedInputPeers host) inputSharingHostNames;
    assert builtins.attrNames fleetEndpoints.remoteWorkspace.hosts == expectedRemoteWorkspaceHosts;
    assert fleetEndpoints.public == [ ];
    assert
      lib.sort builtins.lessThan tailnetGrantBindings == [
        "tcp:22"
        "tcp:22000"
        "udp:4242"
      ];
    pkgsFor.runCommand "network-endpoints-check" { } ''
      touch "$out"
    '';
  identity-policy =
    let
      homeConfig = self.homeConfigurations."${username}@thinkpad".config;
      gitSettings = homeConfig.programs.git.settings;
      sshSettings = homeConfig.programs.ssh.settings;
      identityPolicy = import ../inventory/identities.nix;
    in
    assert identityPolicy.default == "work";
    assert gitSettings.user.useConfigOnly;
    assert gitSettings.user.email == identityPolicy.identities.work.git.email;
    assert
      gitSettings.url."git@github.com:".insteadOf == [
        "https://github.com/"
        "ssh://git@github.com/"
      ];
    assert sshSettings."github.com".data.IdentityFile == "/home/${username}/.ssh/id_work";
    assert sshSettings."github.com-personal".data.IdentityFile == "/home/${username}/.ssh/id_personal";
    assert sshSettings."github.com-work".data.IdentityFile == "/home/${username}/.ssh/id_work";
    assert sshSettings."github.com-kigo".data.IdentityFile == "/home/${username}/.ssh/id_work";
    assert builtins.elem "projects/" identityPolicy.identities.personal.roots;
    assert builtins.elem "nixos-config/" identityPolicy.identities.personal.roots;
    assert identityPolicy.identities.work.aws.profile == "work-readonly";
    assert identityPolicy.identities.personal.aws.profile == "personal-readonly";
    pkgsFor.runCommand "identity-policy-check" { } ''
      touch "$out"
    '';
  tailscale-policy =
    let
      systemConfig = self.nixosConfigurations.thinkpad.config;
      homeConfig = self.homeConfigurations."${username}@thinkpad".config;
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
        "--hostname=thinkpad"
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
    assert fleetSshSettings.thinkpad.data.User == username;
    assert fleetSshSettings.desktop.data.User == username;
    assert fleetSshSettings.victus.data.User == username;
    assert fleetSshSettings.thinkpad.data.ProxyCommand == expectedProxyCommand;
    assert fleetSshSettings.desktop.data.ProxyCommand == expectedProxyCommand;
    assert fleetSshSettings.victus.data.ProxyCommand == expectedProxyCommand;
    pkgsFor.runCommand "tailscale-policy-check" { } ''
      ${lib.getExe tailscalePolicyPrinter} >/dev/null
      touch "$out"
    '';
  syncthing-policy =
    let
      systemConfig = self.nixosConfigurations.thinkpad.config;
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
    assert syncthingPolicy.folders.shared.id == "fleet-shared";
    assert syncthingPolicy.folders.shared.relativePath == "Sync/Fleet";
    pkgsFor.runCommand "syncthing-policy-check" { } ''
      touch "$out"
    '';
  remote-workspace-policy =
    let
      remotePolicy = import ../inventory/remote-workspace.nix;
      systemConfigs = map (name: self.nixosConfigurations.${name}.config) workstationNames;
      homeConfigs = map (name: self.homeConfigurations."${username}@${name}".config) workstationNames;
    in
    assert lib.all (host: !host.features.remoteWorkspace.enable) (builtins.attrValues workstations);
    assert remotePolicy.hosts == { };
    assert self.nixosConfigurations.desktop.config.users.users.${username}.linger == false;
    assert lib.all (
      c:
      (c.users.users.${username}.linger != true)
      && !(builtins.hasAttr "remote-workspace-serve" c.systemd.services)
      && !(builtins.elem remotePolicy.backend.port c.networking.firewall.allowedTCPPorts)
      && !(builtins.elem remotePolicy.backend.port c.networking.firewall.interfaces.tailscale0.allowedTCPPorts)
      && !(builtins.elem 8448 c.networking.firewall.interfaces.tailscale0.allowedTCPPorts)
    ) systemConfigs;
    assert lib.all (c: !(builtins.hasAttr "remote-workspace" c.systemd.user.services)) homeConfigs;
    assert remotePolicy.backend.hostname == "127.0.0.1";
    assert aiToolsPackages ? codex;
    pkgsFor.runCommand "remote-workspace-policy-check" { } ''
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
          ${../scripts/tests/check-input-share.sh} \
          ${../scripts/input-share-reconcile.sh} \
          ${../scripts/syncthing-fleet-reconcile.sh} \
          ${../scripts/lab.sh}
        bash ${../scripts/tests/check-nix-config.sh} ${../scripts/nix-config.sh}
        bash ${../scripts/tests/check-input-share.sh} ${../scripts/input-share-reconcile.sh}
        nix-config --help >/dev/null
        touch "$out"
      '';
}
