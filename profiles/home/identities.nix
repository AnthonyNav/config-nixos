{
  lib,
  pkgs,
  username,
  ...
}:

let
  homeDir = "/home/${username}";
  identities = {
    personal = {
      git = {
        name = "Antonio Zempoaltecatl";
        email = "anthonydevxp@gmail.com";
      };
      githubAlias = "github.com-personal";
      sshKey = "${homeDir}/.ssh/id_personal";
      roots = [
        "${homeDir}/personal/"
        "${homeDir}/nixos-config/"
      ];
    };

    work = {
      git = {
        name = "Antonio Zempoaltecatl";
        email = "antonio.zempoaltecatl@cargomovil.com";
      };
      githubAlias = "github.com-work";
      sshKey = "${homeDir}/.ssh/id_work";
      roots = [ "${homeDir}/work/" ];
    };
  };

  mkGitInclude =
    identity: root:
    {
      condition = "gitdir:${root}";
      contents = {
        user = identity.git;
        url = {
          "git@${identity.githubAlias}:" = {
            insteadOf = [
              "git@github.com:"
              "ssh://git@github.com/"
              "https://github.com/"
            ];
          };
        };
      };
    };

  gitIncludes = lib.concatLists (
    lib.mapAttrsToList (
      _: identity: map (mkGitInclude identity) identity.roots
    ) identities
  );
in

{
  assertions = [
    {
      assertion = identities.personal.sshKey != identities.work.sshKey;
      message = "Personal and work GitHub identities must use different SSH keys.";
    }
  ];

  # Canonical roots make Git identity selection deterministic. Repositories
  # outside these roots have no user.name/user.email and therefore cannot
  # create commits while user.useConfigOnly is enabled.
  home.activation.ensureGitIdentityRoots = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p \
      ${lib.escapeShellArg "${homeDir}/personal"} \
      ${lib.escapeShellArg "${homeDir}/work"}
  '';

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*".AddKeysToAgent = "yes";

      # Never let the generic GitHub hostname choose whichever identity happens
      # to be available in ssh-agent. Git repositories under a managed root
      # rewrite GitHub remotes to one of the explicit aliases below.
      "github.com" = {
        HostName = "github.com";
        IdentityFile = "none";
        IdentityAgent = "none";
        IdentitiesOnly = true;
        User = "git";
      };

      "github.com-personal" = {
        HostName = "github.com";
        IdentityFile = identities.personal.sshKey;
        IdentitiesOnly = true;
        User = "git";
      };

      "github.com-work" = {
        HostName = "github.com";
        IdentityFile = identities.work.sshKey;
        IdentitiesOnly = true;
        User = "git";
      };

      # Backward-compatible alias for existing corporate remotes. New work
      # repositories should use github.com-work.
      "github.com-kigo" = {
        HostName = "github.com";
        IdentityFile = identities.work.sshKey;
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
      user.useConfigOnly = true;
    };
    includes = gitIncludes;
  };
}
