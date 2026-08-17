{
  lib,
  pkgs,
  username,
  ...
}:

let
  policy = import ../../inventory/identities.nix;
  identities = policy.identities;
  homeDir = "/home/${username}";

  rootPath = root: "${homeDir}/${root}";
  sshKeyPath = identity: "${homeDir}/${identity.sshKey}";

  mkGitInclude =
    identity: root:
    {
      condition = "gitdir:${rootPath root}";
      contents.user = identity.git;
    };

  gitIncludes = lib.concatLists (
    lib.mapAttrsToList (
      _: identity: map (mkGitInclude identity) identity.roots
    ) identities
  );

  namespaceEntries = lib.concatLists (
    lib.mapAttrsToList (
      _: identity:
      map (
        namespace:
        {
          name = "git@${identity.github.alias}:${namespace}/";
          value.insteadOf = [
            "https://github.com/${namespace}/"
            "git@github.com:${namespace}/"
            "ssh://git@github.com/${namespace}/"
          ];
        }
      ) identity.github.namespaces
    ) identities
  );

  namespaceRouting = lib.listToAttrs namespaceEntries;
  fallbackRouting = {
    "https://github.com/".insteadOf = [
      "git@github.com:"
      "ssh://git@github.com/"
    ];
  };

  mkSshAlias =
    identity: alias:
    lib.nameValuePair alias {
      HostName = "github.com";
      IdentityFile = sshKeyPath identity;
      IdentitiesOnly = true;
      User = "git";
    };

  sshAliases = lib.listToAttrs (
    lib.concatLists (
      lib.mapAttrsToList (
        _: identity:
        map (mkSshAlias identity) ([ identity.github.alias ] ++ identity.github.compatibilityAliases)
      ) identities
    )
  );

  allNamespaces = lib.concatLists (lib.mapAttrsToList (_: identity: identity.github.namespaces) identities);
  allRoots = lib.concatLists (lib.mapAttrsToList (_: identity: identity.roots) identities);
  allSshAliases = lib.concatLists (
    lib.mapAttrsToList (
      _: identity: [ identity.github.alias ] ++ identity.github.compatibilityAliases
    ) identities
  );
in

{
  imports = [ ../../modules/home/identity-tools.nix ];

  assertions = [
    {
      assertion = identities.personal.sshKey != identities.work.sshKey;
      message = "Personal and work GitHub identities must use different SSH keys.";
    }
    {
      assertion = builtins.length allNamespaces == builtins.length (lib.unique allNamespaces);
      message = "A GitHub namespace may belong to only one identity.";
    }
    {
      assertion = builtins.length allRoots == builtins.length (lib.unique allRoots);
      message = "A Git identity root may belong to only one identity.";
    }
    {
      assertion = builtins.length allSshAliases == builtins.length (lib.unique allSshAliases);
      message = "GitHub SSH aliases must be unique across identities.";
    }
    {
      assertion = policy.githubFallback == "https";
      message = "Unknown GitHub namespaces must fall back to HTTPS.";
    }
  ];

  # Canonical roots make commit identity selection deterministic. Repositories
  # outside these roots have no user.name/user.email and therefore cannot
  # create commits while user.useConfigOnly is enabled.
  home.activation.ensureGitIdentityRoots = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p \
      ${lib.concatMapStringsSep " \\\n      " (root: lib.escapeShellArg (rootPath root)) allRoots}
  '';

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*".AddKeysToAgent = "yes";

      # The generic GitHub hostname is deliberately unusable over SSH. Git URL
      # routing below either selects an explicit identity alias by namespace or
      # converts an unknown SSH-style GitHub URL to HTTPS.
      "github.com" = {
        HostName = "github.com";
        IdentityFile = "none";
        IdentityAgent = "none";
        IdentitiesOnly = true;
        User = "git";
      };

      "debian-server" = {
        HostName = "192.168.1.250";
        IdentityFile = "${homeDir}/.ssh/debian13-server-192.168.1.250";
        IdentitiesOnly = true;
        User = "anthony";
      };
    }
    // sshAliases;
  };

  programs.git = {
    enable = true;
    settings = {
      user.useConfigOnly = true;
      url = fallbackRouting // namespaceRouting;
    };
    includes = gitIncludes;
  };
}
