#!/usr/bin/env python3
"""Invocation-scoped identity routing. Resolution never contacts the network."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys

CONTEXTS = ("neutral", "work", "personal")
RESERVED_WORKSPACES = {"repos", "worktrees", "shared"}
GH_VARIABLES = ("GH_TOKEN", "GITHUB_TOKEN", "GH_ENTERPRISE_TOKEN", "GITHUB_ENTERPRISE_TOKEN", "GH_CONFIG_DIR", "GH_HOST")
GIT_IDENTITY_VARIABLES = ("GIT_AUTHOR_NAME", "GIT_AUTHOR_EMAIL", "GIT_COMMITTER_NAME", "GIT_COMMITTER_EMAIL", "EMAIL", "GIT_SSH", "GIT_SSH_COMMAND", "GIT_SSH_VARIANT", "GIT_CONFIG_PARAMETERS", "GIT_CONFIG_COUNT")
AWS_VARIABLES = ("AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_SECURITY_TOKEN", "AWS_SESSION_TOKEN", "AWS_PROFILE", "AWS_DEFAULT_PROFILE", "AWS_CONFIG_FILE", "AWS_SHARED_CREDENTIALS_FILE", "AWS_ROLE_ARN", "AWS_ROLE_SESSION_NAME", "AWS_WEB_IDENTITY_TOKEN_FILE", "AWS_CONTAINER_CREDENTIALS_FULL_URI", "AWS_CONTAINER_CREDENTIALS_RELATIVE_URI", "AWS_CONTAINER_AUTHORIZATION_TOKEN", "AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE", "AWS_EC2_METADATA_SERVICE_ENDPOINT")


def within(path, root):
    return path == root or root in path.parents


def path_context(config, path):
    path = Path(path).resolve()
    home = Path(config["homeDirectory"]).resolve()
    matches = {name for name, identity in config["policy"]["identities"].items()
               if any(within(path, (home / root).resolve()) for root in identity["roots"])}
    if len(matches) > 1:
        raise ValueError("Overlapping work/personal roots")
    return next(iter(matches), "neutral")


def workspace_location(config, path):
    """Discover the owning project without reading its handoff or credentials."""
    if not path:
        return None
    path = Path(path).resolve()
    home = Path(config["homeDirectory"]).resolve()
    for context in ("work", "personal"):
        parent = home / "Workspace" / context
        if not within(path, parent) or path == parent:
            continue
        name = path.relative_to(parent).parts[0]
        root = parent / name
        handoff = root / "HANDOFF.md"
        if name not in RESERVED_WORKSPACES and not root.is_symlink() and not handoff.is_symlink() and handoff.is_file():
            return {"name": name, "context": context, "root": str(root), "handoff": str(handoff)}
    return None


def git_options(args, cwd=None):
    """Keep Git's own global options and track relative/repeated -C arguments."""
    directory = Path(cwd or Path.cwd()).resolve()
    prefix, index = [], 0
    with_value = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--config-env"}
    while index < len(args) and args[index].startswith("-"):
        arg = args[index]
        prefix.append(arg)
        index += 1
        if arg in with_value:
            if index >= len(args):
                raise ValueError(f"Missing argument for {arg}")
            value = args[index]
            prefix.append(value)
            index += 1
            if arg == "-C" and value:
                directory = (directory / value).resolve()
        elif arg.startswith("-C") and len(arg) > 2:
            directory = (directory / arg[2:]).resolve()
        if arg == "--":
            break
    return prefix, args[index:], directory


def resolve(config, git_prefix=None, directory=None, env=None):
    env = dict(os.environ if env is None else env)
    override = env.get("FLEET_CONTEXT_OVERRIDE")
    if override is not None and override not in CONTEXTS:
        raise ValueError("Invalid explicit context")
    directory = Path(directory or Path.cwd()).resolve()
    probe_env = env.copy()
    for key in GIT_IDENTITY_VARIABLES:
        probe_env.pop(key, None)
    command = [config["binaries"]["git"], *(git_prefix or [])]
    # Always probe the real managed Git, never a PATH-resolved wrapper.
    result = subprocess.run(command + ["rev-parse", "--path-format=absolute", "--git-common-dir"],
                            env=probe_env, capture_output=True, text=True, timeout=10)
    common = result.stdout.strip() if result.returncode == 0 else ""
    common_context = path_context(config, common) if common else "neutral"
    location = directory
    top = subprocess.run(command + ["rev-parse", "--path-format=absolute", "--show-toplevel"],
                         env=probe_env, capture_output=True, text=True, timeout=10)
    explicit_git = bool(env.get("GIT_DIR")) or any(arg == "--git-dir" or arg.startswith("--git-dir=") or arg == "--bare" for arg in (git_prefix or []))
    explicit_tree = bool(env.get("GIT_WORK_TREE")) or any(arg == "--work-tree" or arg.startswith("--work-tree=") for arg in (git_prefix or []))
    if explicit_tree and top.returncode == 0:
        location = Path(top.stdout.strip()).resolve()
    elif explicit_git and common:
        location = Path(common).resolve()
    direct_context = path_context(config, location)
    if direct_context != "neutral" and common_context != "neutral" and direct_context != common_context:
        raise ValueError("Worktree location conflicts with the original repository context")
    context = override or (direct_context if direct_context != "neutral" else common_context)
    direct_workspace = workspace_location(config, location)
    common_workspace = workspace_location(config, common)
    if direct_workspace and common_workspace and direct_workspace["root"] != common_workspace["root"]:
        raise ValueError("Worktree location conflicts with the original workspace")
    return {"context": context, "directory": str(directory), "git_common_dir": common,
            "workspace": common_workspace or direct_workspace,
            "source": "explicit" if override else "path" if direct_context != "neutral" else "git-common-dir" if common_context != "neutral" else "neutral"}


def clean_environment(context, config):
    env = os.environ.copy()
    for key in (*GH_VARIABLES, *AWS_VARIABLES, *GIT_IDENTITY_VARIABLES):
        env.pop(key, None)
    for key in list(env):
        if key.startswith(("AWS_ENDPOINT_URL", "GIT_CONFIG_KEY_", "GIT_CONFIG_VALUE_")):
            env.pop(key)
    env["WORK_CONTEXT"] = context
    env["AWS_EC2_METADATA_DISABLED"] = "true"
    if context != "neutral":
        env["GH_CONFIG_DIR"] = str(Path(config["homeDirectory"]) / ".config/gh" / context)
        env["AWS_PROFILE"] = config["policy"]["identities"][context]["aws"]["profile"]
    wrappers = env.get("FLEET_WRAPPER_BIN")
    if wrappers:
        env["PATH"] = wrappers + os.pathsep + env.get("PATH", "")
    return env


def require_context(context):
    if context == "neutral":
        raise PermissionError("Neutral context has no credentials. Use workspace-context exec {work|personal} -- COMMAND.")


def execute(command, env):
    os.execvpe(command[0], command, env)


def ssh_command(config_path, context):
    return shlex.join([sys.executable, "-B", str(Path(__file__).resolve()), "--config", str(config_path), "git-ssh", context])


def github_helper(config_path, context):
    return "!" + shlex.join([sys.executable, "-B", str(Path(__file__).resolve()), "--config", str(config_path), "gh-" + context, "auth", "git-credential"])


def scoped_git_environment(config, config_path, context, env):
    """Explicit exec scope also reaches SDKs that invoke their own managed Git."""
    identity = config["policy"]["identities"].get(context, {}).get("git", {"name": "", "email": ""})
    settings = [("user.useConfigOnly", "true"), ("user.name", identity["name"]), ("user.email", identity["email"]), ("credential.https://github.com.helper", "")]
    if context != "neutral":
        settings.append(("credential.https://github.com.helper", github_helper(config_path, context)))
    else:
        settings.extend([("credential.helper", ""), ("credential.interactive", "false")])
        env["GIT_TERMINAL_PROMPT"] = "0"
    env["GIT_CONFIG_COUNT"] = str(len(settings))
    for index, (name, value) in enumerate(settings):
        env[f"GIT_CONFIG_KEY_{index}"] = name
        env[f"GIT_CONFIG_VALUE_{index}"] = value
    env["GIT_SSH_COMMAND"] = ssh_command(config_path, context)
    return env


def git_command(config, config_path, args):
    prefix, rest, directory = git_options(args)
    info = resolve(config, prefix, directory)
    context = info["context"]
    env = clean_environment(context, config)
    identity = config["policy"]["identities"].get(context, {}).get("git", {"name": "", "email": ""})
    env["GIT_SSH_COMMAND"] = ssh_command(config_path, context)
    settings = ["-c", "user.useConfigOnly=true", "-c", "user.name=" + identity["name"], "-c", "user.email=" + identity["email"]]
    if context == "neutral":
        settings += ["-c", "credential.helper=", "-c", "credential.https://github.com.helper=", "-c", "credential.interactive=false"]
        env["GIT_TERMINAL_PROMPT"] = "0"
        env["GIT_ASKPASS"] = ""
    else:
        # HTTPS private dependencies use this context's gh token. The helper's
        # explicit context survives Git cloning into a temporary/cache directory.
        helper = github_helper(config_path, context)
        settings += ["-c", "credential.https://github.com.helper=", "-c", "credential.https://github.com.helper=" + helper]
    execute([config["binaries"]["git"], *prefix, *settings, *rest], env)


def git_ssh(config, args):
    context, *ssh_args = args
    if context not in CONTEXTS:
        raise ValueError("Invalid SSH context")
    aliases = {"github.com": None}
    for name, identity in config["policy"]["identities"].items():
        aliases[identity["github"]["alias"]] = name
        for alias in identity["github"].get("compatibilityAliases", []):
            aliases[alias] = name
    index = 0
    while index < len(ssh_args):
        arg = ssh_args[index]
        if arg in ("-B", "-b", "-c", "-D", "-E", "-e", "-F", "-I", "-i", "-J", "-L", "-l", "-m", "-O", "-o", "-p", "-Q", "-R", "-S", "-W", "-w"):
            index += 2
        elif arg.startswith("-"):
            index += 1
        else:
            break
    if index < len(ssh_args):
        destination = ssh_args[index]
        host = destination.rsplit("@", 1)[-1]
        if host in aliases:
            require_context(context)
            if aliases[host] is not None and aliases[host] != context:
                raise PermissionError("GitHub SSH alias conflicts with the selected workspace")
            identity = config["policy"]["identities"][context]
            # GitHub always uses the SSH transport user `git`. Our -F /dev/null
            # intentionally removes account-independent ~/.ssh/config routing.
            ssh_args[index] = "git@github.com"
            ssh_args = ["-F", "/dev/null", "-i", str(Path(config["homeDirectory"]) / identity["sshKey"]), "-o", "IdentitiesOnly=yes", *ssh_args]
    if os.environ.get("GIT_TERMINAL_PROMPT") == "0":
        ssh_args = ["-o", "BatchMode=yes", *ssh_args]
    execute([config["binaries"]["ssh"], *ssh_args], os.environ.copy())


def aws_command(config, action, args, context):
    if action in ("aws-work", "aws-personal"):
        context = action.removeprefix("aws-")
    if action in ("aws-login", "aws-profile-setup"):
        if not args or args[0] not in ("work", "personal") or len(args) != 1:
            raise ValueError(f"Usage: {action} {{work|personal}}")
        context = args[0]
        args = ["sso", "login"] if action == "aws-login" else ["configure", "sso"]
    elif action == "aws-whoami":
        if len(args) > 1 or (args and args[0] not in ("work", "personal", "current")):
            raise ValueError("Usage: aws-whoami [current|work|personal]")
        context = args[0] if args and args[0] != "current" else context
        args = ["sts", "get-caller-identity"]
    elif args in (["--version"], ["help"], ["--help"]):
        execute([config["binaries"]["aws"], *args], clean_environment("neutral", config))
    else:
        if any(arg == "--profile" or arg.startswith("--profile=") for arg in args):
            raise PermissionError("--profile is blocked; use aws-work/aws-personal")
        if len(args) < 2:
            raise ValueError("Usage: aws SERVICE READ_OPERATION [ARGS...]")
        service, operation = args[:2]
        allowed = ("get-", "list-", "describe-", "head-", "lookup-", "search-", "batch-get-", "select-", "filter-", "validate-", "download-")
        if not ((service, operation) == ("s3", "ls") or operation in ("scan", "query", "tail") or operation.startswith(allowed)):
            raise PermissionError("Blocked non-read AWS operation; the IAM role must also enforce read-only access")
    require_context(context)
    env = clean_environment(context, config)
    execute([config["binaries"]["aws"], "--profile", env["AWS_PROFILE"], *args], env)


def gh_command(config, action, args, context):
    if action in ("gh-work", "gh-personal"):
        context = action.removeprefix("gh-")
    if action == "gh-login":
        if len(args) != 1 or args[0] not in ("work", "personal"):
            raise ValueError("Usage: gh-login {work|personal}")
        context = args[0]
        args = ["auth", "login", "--hostname", "github.com", "--git-protocol", "ssh", "--web", "--skip-ssh-key"]
    elif action == "gh-whoami":
        if len(args) > 1 or (args and args[0] not in ("work", "personal", "current")):
            raise ValueError("Usage: gh-whoami [current|work|personal]")
        context = args[0] if args and args[0] != "current" else context
        args = ["api", "--hostname", "github.com", "user", "--jq", ".login"]
    elif not args or args[0] in ("help", "--help", "-h", "version", "--version"):
        env = clean_environment("neutral", config)
        env["GH_CONFIG_DIR"] = "/dev/null"
        execute([config["binaries"]["gh"], *args], env)
    require_context(context)
    execute([config["binaries"]["gh"], *args], clean_environment(context, config))


def status(config, info):
    context = info["context"]
    identity = config["policy"]["identities"].get(context, {})
    return info | {"git_email": identity.get("git", {}).get("email"),
                   "gh_config_dir": str(Path(config["homeDirectory"]) / ".config/gh" / context) if identity else None,
                   "aws_profile": identity.get("aws", {}).get("profile")}


def doctor(config, info):
    print(json.dumps(status(config, info), indent=2))
    home = Path(config["homeDirectory"])
    for name, identity in config["policy"]["identities"].items():
        print(f'{name}: SSH key {"present" if (home / identity["sshKey"]).is_file() else "not provisioned"}; GitHub login {"configured" if (home / ".config/gh" / name / "hosts.yml").is_file() else "not provisioned"}')
    for binary in ("git", "gh", "aws"):
        print(f"{binary}: {shutil.which(binary) or 'MISSING'}")
    print("Credentials were not read; no network authentication was attempted.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("action")
    parser.add_argument("arguments", nargs=argparse.REMAINDER)
    options = parser.parse_args()
    try:
        config = json.loads(options.config.read_text())
        args, action = options.arguments, options.action
        if action == "git":
            git_command(config, options.config, args)
        elif action == "git-ssh":
            git_ssh(config, args)
        elif action == "workspace":
            spec = importlib.util.spec_from_file_location("portable_workspace", Path(__file__).with_name("workspace.py"))
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            return module.main(config, options.config, args, sys.modules[__name__])
        else:
            info = resolve(config)
            if action.startswith("aws"):
                aws_command(config, action, args, info["context"])
            elif action.startswith("gh"):
                gh_command(config, action, args, info["context"])
            elif action == "identity-doctor" or (action in ("workspace-context", "work-context") and args == ["doctor"]):
                doctor(config, info)
            elif action in ("workspace-context", "work-context") and (not args or args[0] == "status"):
                if args == ["status", "--name"]:
                    print(info["context"])
                elif args in ([], ["status"]):
                    print(json.dumps(status(config, info), indent=2))
                else:
                    raise ValueError("Usage: workspace-context status [--name]")
            elif action in ("workspace-context", "work-context") and len(args) >= 4 and args[0] == "exec" and args[1] in CONTEXTS and args[2] == "--":
                env = clean_environment(args[1], config)
                env["FLEET_CONTEXT_OVERRIDE"] = args[1]
                env = scoped_git_environment(config, options.config, args[1], env)
                execute(args[3:], env)
            else:
                raise ValueError("Usage: workspace-context {status|doctor|exec CONTEXT -- COMMAND}")
        return 0
    except PermissionError as error:
        print(f"workspace-context: {error}", file=sys.stderr)
        return 77
    except (ValueError, OSError, subprocess.TimeoutExpired) as error:
        # Parser exceptions can carry an entire credential-bearing document.
        message = str(error) if isinstance(error, ValueError) and not isinstance(error, json.JSONDecodeError) else type(error).__name__
        print(f"workspace-context: {message}", file=sys.stderr)
        return 64


if __name__ == "__main__":
    raise SystemExit(main())
