{
  lib,
  pkgs,
  username,
  ...
}:

let
  policy = import ../../inventory/identities.nix;
  identities = policy.identities;
  defaultIdentity = identities.${policy.default};
  personalIdentity = identities.personal;
  homeDir = "/home/${username}";

  rootPath = root: "${homeDir}/${root}";
  sshKeyPath = identity: "${homeDir}/${identity.sshKey}";

  personalIncludes = map (root: {
    condition = "gitdir:${rootPath root}";
    contents.user = personalIdentity.git;
  }) personalIdentity.roots;

  allRoots = personalIdentity.roots;
in
{
  imports = [
    ../../modules/home/identity-tools.nix
    ../../modules/home/work-context.nix
  ];

  assertions = [
    {
      assertion = policy.default == "work";
      message = "The default development identity must remain work.";
    }
    {
      assertion = identities.personal.sshKey != identities.work.sshKey;
      message = "Personal and work GitHub identities must use different SSH keys.";
    }
    {
      assertion = builtins.length allRoots == builtins.length (lib.unique allRoots);
      message = "Personal Git identity roots must be unique.";
    }
  ];

  home.activation.ensureGitIdentityRoots = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p \
      ${lib.concatMapStringsSep " \\\n      " (root: lib.escapeShellArg (rootPath root)) allRoots}
  '';

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*".AddKeysToAgent = "yes";

      # GitHub is work by default. Personal shells override the key through
      # GIT_SSH_COMMAND so dependency managers inherit the same context.
      "github.com" = {
        HostName = "github.com";
        IdentityFile = sshKeyPath defaultIdentity;
        IdentitiesOnly = true;
        User = "git";
      };

      "github.com-work" = {
        HostName = "github.com";
        IdentityFile = sshKeyPath identities.work;
        IdentitiesOnly = true;
        User = "git";
      };

      "github.com-kigo" = {
        HostName = "github.com";
        IdentityFile = sshKeyPath identities.work;
        IdentitiesOnly = true;
        User = "git";
      };

      "github.com-personal" = {
        HostName = "github.com";
        IdentityFile = sshKeyPath personalIdentity;
        IdentitiesOnly = true;
        User = "git";
      };

      "debian-server" = {
        HostName = "192.168.1.250";
        IdentityFile = "${homeDir}/.ssh/debian13-server-192.168.1.250";
        IdentitiesOnly = true;
        User = "anthony";
      };
    };
  };

  programs.git = {
    enable = true;
    settings = {
      user = defaultIdentity.git // {
        useConfigOnly = true;
      };

      # Package managers frequently invoke plain HTTPS GitHub URLs. Normalize
      # them to github.com, whose default SSH identity is the work key.
      url."git@github.com:".insteadOf = [
        "https://github.com/"
        "ssh://git@github.com/"
      ];
    };
    includes = personalIncludes;
  };
}
