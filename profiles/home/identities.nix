{
  config,
  lib,
  pkgs,
  ...
}:
let
  policy = import ../../inventory/identities.nix;
  inherit (policy) identities;
  homeDir = config.home.homeDirectory;
  roots = lib.concatMap (identity: identity.roots) (builtins.attrValues identities);
  key = identity: "${homeDir}/${identity.sshKey}";
  githubHost = identity: {
    HostName = "github.com";
    IdentityFile = key identity;
    IdentitiesOnly = true;
    User = "git";
  };
  tools = import ../../packages/workspace-tools.nix {
    inherit pkgs lib;
    homeDirectory = homeDir;
  };
  gitInvocation =
    context: action:
    lib.escapeShellArgs [
      "${pkgs.python3}/bin/python3"
      "-B"
      (toString ../../scripts/workspace-context.py)
      "--config"
      (toString tools.configuration)
      action
      context
    ];
in
{
  imports = [
    ../../modules/home/identity-tools.nix
    ../../modules/home/work-context.nix
  ];
  assertions = [
    {
      assertion = policy.default == "neutral";
      message = "Unmanaged directories must use neutral context.";
    }
    {
      assertion = identities.personal.sshKey != identities.work.sshKey;
      message = "Work and personal SSH keys must differ.";
    }
    {
      assertion = builtins.length roots == builtins.length (lib.unique roots);
      message = "Workspace identity roots must be unique.";
    }
  ];
  home.activation.ensureGitIdentityRoots = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.coreutils}/bin/mkdir -p ${
      lib.escapeShellArgs (
        map (root: "${homeDir}/${root}") roots
        ++
          lib.concatMap
            (
              context:
              map (child: "${homeDir}/Workspace/${context}/${child}") [
                "repos"
                "worktrees"
                "shared"
              ]
            )
            [
              "work"
              "personal"
            ]
      )
    }
    run ${pkgs.coreutils}/bin/install -d -m 0700 \
      ${lib.escapeShellArg "${homeDir}/.config/gh/work"} ${lib.escapeShellArg "${homeDir}/.config/gh/personal"}
  '';
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*".AddKeysToAgent = "yes";
      "github.com" = {
        HostName = "github.com";
        User = "git";
        IdentityFile = "none";
        IdentityAgent = "none";
        IdentitiesOnly = true;
      };
      "github.com-work" = githubHost identities.work;
      "github.com-kigo" = githubHost identities.work;
      "github.com-personal" = githubHost identities.personal;
    };
  };
  programs.git = {
    enable = true;
    settings.user.useConfigOnly = true;
    # Conditional configuration also covers clients that use their own Git.
    # The invocation wrapper covers external linked worktrees and git -C.
    includes = lib.concatLists (
      lib.mapAttrsToList (
        context: identity:
        map (root: {
          condition = "gitdir:${homeDir}/${root}";
          contents = {
            user = identity.git;
            core.sshCommand = gitInvocation context "git-ssh";
            credential."https://github.com".helper = [
              ""
              (
                "!"
                + lib.escapeShellArgs [
                  "${pkgs.python3}/bin/python3"
                  "-B"
                  (toString ../../scripts/workspace-context.py)
                  "--config"
                  (toString tools.configuration)
                  "gh-${context}"
                  "auth"
                  "git-credential"
                ]
              )
            ];
          };
        }) identity.roots
      ) identities
    );
  };
}
