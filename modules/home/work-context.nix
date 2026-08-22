{
  lib,
  pkgs,
  username,
  ...
}:

let
  policy = import ../../inventory/identities.nix;
  identities = policy.identities;
  work = identities.work;
  personal = identities.personal;
  homeDir = "/home/${username}";
  personalRoots = map (root: "${homeDir}/${root}") personal.roots;

  personalSsh = pkgs.writeShellScript "git-ssh-personal" ''
    exec ${pkgs.openssh}/bin/ssh \
      -i ${lib.escapeShellArg "${homeDir}/${personal.sshKey}"} \
      -o IdentitiesOnly=yes \
      "$@"
  '';

  awsReadOnly = pkgs.writeShellApplication {
    name = "aws";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      profile="''${AWS_PROFILE:-${work.aws.profile}}"

      case "$profile" in
        ${work.aws.profile}|${personal.aws.profile}) ;;
        *)
          printf 'aws: profile %q is not an approved read-only profile.\n' "$profile" >&2
          exit 64
          ;;
      esac

      for arg in "$@"; do
        case "$arg" in
          --profile|--profile=*)
            printf 'aws: --profile is blocked; use the current context or aws-work/aws-personal.\n' >&2
            exit 64
            ;;
        esac
      done

      if [[ $# -eq 0 ]]; then
        printf 'Usage: aws SERVICE READ_OPERATION [ARGS...]\n' >&2
        printf 'Approved profiles: ${work.aws.profile}, ${personal.aws.profile}\n' >&2
        exit 64
      fi

      if [[ "$1" == "--version" || "$1" == "help" ]]; then
        exec ${pkgs.awscli2}/bin/aws "$@"
      fi

      if [[ $# -lt 2 ]]; then
        printf 'aws: expected SERVICE OPERATION.\n' >&2
        exit 64
      fi

      service="$1"
      operation="$2"

      case "$service:$operation" in
        s3:ls) ;;
        *:get-*|*:list-*|*:describe-*|*:head-*|*:lookup-*|*:search-*|*:batch-get-*|*:select-*|*:scan|*:query|*:filter-*|*:tail|*:validate-*|*:download-*) ;;
        *)
          printf 'aws: blocked non-read operation: %s %s\n' "$service" "$operation" >&2
          printf 'The underlying AWS profile must also be backed by a read-only IAM role.\n' >&2
          exit 77
          ;;
      esac

      unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_WEB_IDENTITY_TOKEN_FILE AWS_ROLE_ARN
      exec ${pkgs.awscli2}/bin/aws --profile "$profile" "$@"
    '';
  };

  mkAwsFixed = name: profile: pkgs.writeShellApplication {
    inherit name;
    text = ''
      export AWS_PROFILE=${lib.escapeShellArg profile}
      exec ${lib.getExe awsReadOnly} "$@"
    '';
  };

  awsWork = mkAwsFixed "aws-work" work.aws.profile;
  awsPersonal = mkAwsFixed "aws-personal" personal.aws.profile;

  awsLogin = pkgs.writeShellApplication {
    name = "aws-login";
    text = ''
      case "''${1:-}" in
        work) profile=${lib.escapeShellArg work.aws.profile} ;;
        personal) profile=${lib.escapeShellArg personal.aws.profile} ;;
        *)
          printf 'Usage: aws-login {work|personal}\n' >&2
          exit 64
          ;;
      esac
      exec ${pkgs.awscli2}/bin/aws sso login --profile "$profile"
    '';
  };

  awsProfileSetup = pkgs.writeShellApplication {
    name = "aws-profile-setup";
    text = ''
      case "''${1:-}" in
        work) profile=${lib.escapeShellArg work.aws.profile} ;;
        personal) profile=${lib.escapeShellArg personal.aws.profile} ;;
        *)
          printf 'Usage: aws-profile-setup {work|personal}\n' >&2
          exit 64
          ;;
      esac
      exec ${pkgs.awscli2}/bin/aws configure sso --profile "$profile"
    '';
  };

  awsWhoami = pkgs.writeShellApplication {
    name = "aws-whoami";
    text = ''
      case "''${1:-current}" in
        current) profile="''${AWS_PROFILE:-${work.aws.profile}}" ;;
        work) profile=${lib.escapeShellArg work.aws.profile} ;;
        personal) profile=${lib.escapeShellArg personal.aws.profile} ;;
        *)
          printf 'Usage: aws-whoami [current|work|personal]\n' >&2
          exit 64
          ;;
      esac
      exec ${pkgs.awscli2}/bin/aws --profile "$profile" sts get-caller-identity
    '';
  };

  contextStatus = pkgs.writeShellApplication {
    name = "work-context";
    text = ''
      printf 'context=%s\n' "''${WORK_CONTEXT:-work}"
      printf 'aws_profile=%s\n' "''${AWS_PROFILE:-${work.aws.profile}}"
      if [[ -n "''${GIT_SSH_COMMAND:-}" ]]; then
        printf 'git_ssh=personal\n'
      else
        printf 'git_ssh=work-default\n'
      fi
    '';
  };
in
{
  home.sessionVariables = {
    AWS_PROFILE = work.aws.profile;
    WORK_CONTEXT = "work";
  };

  home.packages = [
    awsReadOnly
    awsWork
    awsPersonal
    awsLogin
    awsProfileSetup
    awsWhoami
    contextStatus
  ];

  programs.zsh.initContent = lib.mkAfter ''
    _update_work_context() {
      case "$PWD/" in
        ${lib.concatMapStringsSep "|" (root: "${root}*") personalRoots})
          export WORK_CONTEXT=personal
          export AWS_PROFILE=${lib.escapeShellArg personal.aws.profile}
          export GIT_SSH_COMMAND=${lib.escapeShellArg (toString personalSsh)}
          ;;
        *)
          export WORK_CONTEXT=work
          export AWS_PROFILE=${lib.escapeShellArg work.aws.profile}
          unset GIT_SSH_COMMAND
          ;;
      esac
    }

    autoload -Uz add-zsh-hook
    add-zsh-hook chpwd _update_work_context
    _update_work_context
  '';
}
