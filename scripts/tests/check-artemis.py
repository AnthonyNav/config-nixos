#!/usr/bin/env python3
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('launcher', sys.argv[1])
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)
sys.argv = sys.argv[:1]


class Artemis(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.src = self.root / 'upstream'
        self.src.mkdir()
        (self.src / 'uv.lock').write_text('locked fixture')
        (self.src / 'start.sh').write_text('NEVER EXECUTE')
        self.config = dict(revision='fixed', runtimeId='runtime', source=str(self.src),
                           python='/pinned/python', uv='/pinned/uv',
                           binPath='/pinned/bin', libraryPath='/pinned/lib')
        self.runtime = self.root / 'data/fleet-artemis/runtime'
        self.cwd = os.getcwd()
        self.addCleanup(os.chdir, self.cwd)
        self.env = patch.dict(os.environ, {
            'HOME': str(self.root / 'home'), 'XDG_DATA_HOME': str(self.root / 'data'),
            'PATH': '/original/bin', 'LD_LIBRARY_PATH': '/original/lib',
            'ARTEMIS_NOTIFY_CMD': 'unwanted-hook',
        }, clear=True)
        self.env.start()
        self.addCleanup(self.env.stop)
        self.addCleanup(os.umask, os.umask(0o077))

    def prepare(self):
        with patch.object(launcher.subprocess, 'run') as run:
            launcher.main(self.config, ['prepare'])
            return run

    def test_missing_runtime_never_installs_or_writes(self):
        with patch.object(launcher.subprocess, 'run') as run:
            with self.assertRaises(ValueError):
                launcher.main(self.config, ['mcp'])
            run.assert_not_called()
        self.assertFalse(self.runtime.exists())

    def test_installers_and_extra_mcp_arguments_rejected(self):
        for args in [['init'], ['mcp', '--install', 'all'], ['prepare', '--upgrade']]:
            with self.assertRaises(ValueError):
                launcher.main(self.config, args)
        self.assertFalse(self.runtime.exists())

    def test_prepare_is_explicit_locked_and_idempotent(self):
        run = self.prepare()
        call = run.call_args
        self.assertEqual(call.args[0], ['/pinned/uv', 'sync', '--frozen', '--no-dev', '--python', '/pinned/python'])
        self.assertEqual(call.kwargs['env']['UV_PYTHON_DOWNLOADS'], 'never')
        self.assertEqual((self.runtime / 'source/uv.lock').read_text(), 'locked fixture')
        self.assertTrue((self.runtime / 'ready').is_file())
        self.assertEqual(self.runtime.stat().st_mode & 0o777, 0o700)
        self.prepare().assert_not_called()

    def test_failed_prepare_not_marked_ready_and_retry_works(self):
        with patch.object(launcher.subprocess, 'run', side_effect=subprocess.CalledProcessError(1, 'uv')):
            with self.assertRaises(subprocess.CalledProcessError):
                launcher.main(self.config, ['prepare'])
        self.assertFalse((self.runtime / 'ready').exists())
        self.prepare().assert_called_once()

    def test_mcp_is_stdio_and_child_environment_is_scoped(self):
        self.prepare()
        with patch.object(launcher.os, 'execve') as execute:
            launcher.main(self.config, ['mcp'])
        executable, args, env = execute.call_args.args
        self.assertEqual(args, [executable, '-m', 'mcp_server'])
        self.assertEqual(env['LD_LIBRARY_PATH'], '/pinned/lib')
        self.assertEqual(env['ARTEMIS_HELPER_AUTO_INSTALL'], 'false')
        self.assertEqual(env['ARTEMIS_KEEP_DEVICE_AWAKE'], 'false')
        self.assertNotIn('ARTEMIS_NOTIFY_CMD', env)
        self.assertEqual(os.environ['LD_LIBRARY_PATH'], '/original/lib')
        self.assertFalse((self.root / 'home').exists())

    def test_run_arguments_preserved_without_shell_execution(self):
        self.prepare()
        prompt = 'Tap "Settings"; $(do-not-execute)'
        with patch.object(launcher.os, 'execve') as execute:
            launcher.main(self.config, ['run', prompt, '--profile', 'pro'])
        self.assertEqual(execute.call_args.args[1][-4:], ['run', prompt, '--profile', 'pro'])

    def test_status_is_read_only(self):
        with contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(launcher.main(self.config, ['status']), 1)
        self.assertIn('Prepared: False', output.getvalue())
        self.assertFalse(self.runtime.exists())


unittest.main()
