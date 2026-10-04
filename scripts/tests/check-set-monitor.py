#!/usr/bin/env python3
"""Exercise the manual monitor command with fake IPC; never touch a session."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

script = Path(sys.argv.pop(1)).resolve()

FAKE_TOOL = """
import json, os, sys
from pathlib import Path
tool = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ['MONITOR_TEST_LOG'], 'a') as log:
    log.write(json.dumps([tool, args, os.environ.get('LD_LIBRARY_PATH')]) + '\\n')
if tool == 'hyprctl':
    if args == ['monitors', '-j']:
        print(os.environ['MONITOR_TEST_SCREENS'])
    else:
        print(os.environ.get('MONITOR_TEST_REPLY', 'ok'))
        sys.exit(int(os.environ.get('MONITOR_TEST_EXIT', '0')))
elif tool == 'systemctl' and 'is-active' in args:
    sys.exit(0 if os.environ.get('MONITOR_TEST_AUTO', 'on') == 'on' else 3)
"""


def screen(name, width=1920, height=1080, **extra):
    return dict(name=name, description=name, width=width, height=height,
                x=0, y=0, scale=1, transform=0, **extra)


class ManualMonitorTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        tools = self.root / "bin"
        tools.mkdir()
        for name in ("hyprctl", "systemctl", "caelestia", "notify-send", "sleep"):
            path = tools / name
            path.write_text(f"#!{sys.executable}\n" + FAKE_TOOL)
            path.chmod(0o755)
        self.log = self.root / "commands.jsonl"
        self.env = dict(os.environ, PATH=f'{tools}:{os.environ["PATH"]}',
                        LD_LIBRARY_PATH="/untrusted/project/libraries",
                        MONITOR_TEST_LOG=str(self.log))
        self.screens = [screen("eDP-2"), screen("DP-3")]

    def run_command(self, *args):
        self.env["MONITOR_TEST_SCREENS"] = json.dumps(self.screens)
        result = subprocess.run(["bash", str(script), *args], env=self.env,
                                capture_output=True, text=True, timeout=5)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []
        return result, calls

    def test_scaled_portrait_anchor_and_manual_pause(self):
        self.screens[0].update(transform=1, scale=1.5, x=10, y=20)
        result, calls = self.run_command("right", "portrait-inv")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(["keyword", "monitor", "DP-3,preferred,730x20,1,transform,3"],
                      [args for tool, args, _ in calls if tool == "hyprctl"])
        stop = next(i for i, call in enumerate(calls) if call[1] == ["--user", "stop", "monitor-layout.service"])
        apply = next(i for i, call in enumerate(calls) if call[0] == "hyprctl" and call[1][0] == "keyword")
        self.assertLess(stop, apply)
        self.assertTrue(all(ld_path is None for _, _, ld_path in calls))

    def test_three_monitors_require_explicit_target_and_anchor(self):
        self.screens.append(screen("HDMI-A-1", 2560, 1440))
        result, calls = self.run_command("left", "portrait", "DP-3")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(tool == "systemctl" for tool, _, _ in calls))

    def test_invalid_input_never_pauses_automation(self):
        for args in (("diagonal",), ("left", "bad"),
                     ("left", "normal", "missing", "eDP-2"),
                     ("left", "normal", "DP-3", "DP-3")):
            with self.subTest(args=args):
                result, calls = self.run_command(*args)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(any(tool == "systemctl" for tool, _, _ in calls))

    def test_ipc_failure_restores_only_previously_active_automation(self):
        for active, reply, status in (("on", "invalid mode", "0"), ("on", "disconnected", "1"), ("off", "invalid mode", "0")):
            with self.subTest(active=active, status=status):
                if self.log.exists():
                    self.log.unlink()
                self.env.update(MONITOR_TEST_AUTO=active, MONITOR_TEST_REPLY=reply, MONITOR_TEST_EXIT=status)
                result, calls = self.run_command("left")
                self.assertNotEqual(result.returncode, 0)
                starts = [args for tool, args, _ in calls if tool == "systemctl" and "start" in args]
                self.assertEqual(bool(starts), active == "on")
                self.assertFalse(any(tool == "notify-send" for tool, _, _ in calls))


unittest.main()
