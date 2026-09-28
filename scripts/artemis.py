#!/usr/bin/env python3
"""Explicit local Artemis lifecycle. Never run upstream installers or edit harnesses."""
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def main(config, argv):
    if not argv or argv[0] in ('--help', '-h'):
        print('Usage: fleet-artemis prepare | status | mcp | run ARGS... | doctor ARGS...')
        return 0
    action, *args = argv
    if action not in ('prepare', 'status', 'mcp', 'run', 'doctor'):
        raise ValueError('Unsupported action. Use --help; upstream global installers are not exposed.')
    if action in ('prepare', 'status', 'mcp') and args:
        raise ValueError(f'{action} takes no arguments')
    root = Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share'))) / 'fleet-artemis'
    runtime = root / config['runtimeId']
    source = runtime / 'source'
    ready = runtime / 'ready'
    if action == 'status':
        print(f"Revision: {config['revision']}\nRuntime: {runtime}\nPrepared: {ready.is_file()}")
        return 0 if ready.is_file() else 1
    # No install/download as a side effect of an MCP client starting.
    if action != 'prepare' and not ready.is_file():
        raise ValueError('Artemis is not prepared. Run fleet-artemis prepare explicitly first.')
    os.umask(0o077)
    if action == 'prepare':
        runtime.mkdir(parents=True, exist_ok=True, mode=0o700)
        with (runtime / 'prepare.lock').open('w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            if ready.is_file():
                print('Pinned runtime already prepared.')
                return 0
            if not source.exists():
                staging = runtime / 'source.partial'
                if staging.exists():
                    shutil.rmtree(staging)
                shutil.copytree(config['source'], staging, copy_function=shutil.copy2)
                for path in [staging, *staging.rglob('*')]:
                    if not path.is_symlink():
                        path.chmod(path.stat().st_mode | (0o700 if path.is_dir() else 0o600))
                staging.rename(source)
            env = os.environ.copy()
            env['UV_PROJECT_ENVIRONMENT'] = str(source / '.venv')
            env['UV_PYTHON_DOWNLOADS'] = 'never'
            env['UV_NO_CONFIG'] = '1'
            subprocess.run([config['uv'], 'sync', '--frozen', '--no-dev', '--python', config['python']],
                           cwd=source, env=env, check=True)
            ready.write_text(config['revision'] + '\n')
            print('Prepared. No device task or assistant configuration was changed.')
        return 0
    env = os.environ.copy()
    # These paths affect only the Artemis process and its descendants.
    env['PATH'] = config['binPath'] + os.pathsep + env.get('PATH', '')
    env['LD_LIBRARY_PATH'] = config['libraryPath']
    env['ARTEMIS_APP_DIR'] = str(root / 'data')
    env['ARTEMIS_HELPER_AUTO_INSTALL'] = 'false'
    env['ARTEMIS_KEEP_DEVICE_AWAKE'] = 'false'
    env['ARTEMIS_DESKTOP_NOTIFY'] = 'false'
    # Disable ambient notification hooks for this optional integration.
    for key in ('ARTEMIS_NOTIFY_CMD', 'OPENCLAW_WEBHOOK_URL', 'MCP_NOTIFICATION_WEBHOOK', 'ARTEMIS_WEBHOOK_URL'):
        env.pop(key, None)
    os.chdir(source)
    executable = str(source / '.venv/bin/python')
    command = [executable, '-m', 'mcp_server'] if action == 'mcp' else [executable, '-m', 'artemis', action, *args]
    os.execve(executable, command, env)


if __name__ == '__main__':
    try:
        settings = json.loads(Path(sys.argv[1]).read_text())
        sys.exit(main(settings, sys.argv[2:]))
    except (ValueError, OSError) as error:
        print(f'fleet-artemis: {error}', file=sys.stderr)
        sys.exit(1)
    except subprocess.CalledProcessError:
        print('fleet-artemis: preparation failed; runtime is not ready. Retry prepare after fixing the error.', file=sys.stderr)
        sys.exit(1)
