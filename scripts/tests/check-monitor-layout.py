#!/usr/bin/env python3
import importlib.util
import contextlib
import io
import json
import sys
import unittest
import subprocess
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("monitor_layout", sys.argv.pop(1))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
displays = json.loads(Path(sys.argv.pop(1)).read_text())


def monitor(name, width=1920, height=1080, scale=1, transform=0, **extra):
    return dict(name=name, make="Generic", model=name, serial="test",
                width=width, height=height, scale=scale, transform=transform,
                x=0, y=0, refreshRate=60, **extra)


def known(role, name):
    d = displays[role]
    make_model, serial = d["criteria"].rsplit(" ", 1)
    if role == "center":
        make, model = "LG Electronics", "LG IPS QHD"
        width, height = 2560, 1440
    else:
        make, model = make_model.split(" ", 1)
        width, height = 1920, 1080
    return dict(monitor(name, width, height), make=make, model=model,
                serial="" if serial == "Unknown" else serial,
                availableModes=[d["mode"]])


class LayoutTests(unittest.TestCase):
    def test_confirmed_physical_studio_order_and_rotation(self):
        # Real EDIDs, independent of the policy: deriving these with known()
        # would let swapped left/right identities pass the regression test.
        center = dict(monitor("HDMI-A-1", 2560, 1440),
                      make="LG Electronics", model="LG IPS QHD", serial="506TFNE0N927",
                      availableModes=["2560x1440@99.95Hz"])
        left = dict(monitor("DP-2"), make="HGC", model="CR270C", serial="0000000000001",
                    availableModes=["1920x1080@165.00Hz"])
        right = dict(monitor("DP-3"), make="XXX", model="CR270C-P", serial="",
                     availableModes=["1920x1080@165.00Hz"])
        for screens, profile, positions in (
            ([right, center, left], "studio",
             [("HDMI-A-1", 0, 0), ("DP-2", -1080, 1), ("DP-3", 2560, 3)]),
            ([right, left], "studio-pair", [("DP-2", -1080, 1), ("DP-3", 0, 3)]),
        ):
            with self.subTest(profile=profile):
                name, rules = module.plan(screens, displays)
                self.assertEqual(name, profile)
                self.assertEqual([(r["name"], r["x"], r["transform"]) for r in rules], positions)
                self.assertTrue(all(r["y"] == 0 and r["scale"] == 1 for r in rules))
                self.assertTrue(all(r["mode"] == "1920x1080@165" for r in rules
                                    if r["name"] != "HDMI-A-1"))

    def test_laptop_two_externals(self):
        screens = [monitor("DP-2"), monitor("eDP-2", scale=1.25), monitor("HDMI-A-1")]
        name, rules = module.plan(screens, displays)
        self.assertEqual(name, "portable-3")
        self.assertEqual(rules[0]["name"], "eDP-2")
        self.assertEqual([r["x"] for r in rules], [0, 1536, 3456])

    def test_three_known_change_connectors(self):
        screens = [known("right", "DP-7"), known("center", "HDMI-A-4"), known("left", "DP-8")]
        name, rules = module.plan(screens, displays)
        self.assertEqual(name, "studio")
        self.assertEqual([(r["x"], r["transform"]) for r in rules], [(0, 0), (-1080, 1), (2560, 3)])
        self.assertEqual(rules[0]["mode"], "2560x1440@99.95")

    def test_two_known_with_internal_and_undock(self):
        screens = [known("center", "DP-1"), known("left", "DP-2"), monitor("eDP-1")]
        name, rules = module.plan(screens, displays)
        self.assertEqual(name, "studio-pair")
        self.assertEqual(rules[-1]["y"], 1920)
        _, rules = module.plan(screens[-1:], displays)
        self.assertEqual((rules[0]["x"], rules[0]["y"], rules[0]["transform"]), (0, 0, 0))

    def test_portrait_pair(self):
        _, rules = module.plan([known("left", "DP-1"), known("right", "DP-2")], displays)
        self.assertEqual([r["x"] for r in rules], [-1080, 0])

    def test_unplug_scaled_fallback(self):
        screens = [monitor("DP-1", transform=3, scale=1.5), monitor("DP-2")]
        _, rules = module.plan(screens, displays)
        self.assertEqual(rules[1]["x"], 1280)
        self.assertTrue(all(r["transform"] == 0 for r in rules))
        _, rules = module.plan(screens[1:], displays)
        self.assertEqual(rules[0]["x"], 0)

    def test_duplicate_identity_or_unsupported_mode_uses_safe_fallback(self):
        screens = [known("left", "DP-1"), known("left", "DP-2")]
        self.assertEqual(module.plan(screens, displays)[0], "portable-2")
        screens = [known("left", "DP-1"), known("center", "DP-2")]
        screens[0]["availableModes"] = ["1920x1080@60Hz"]
        self.assertEqual(module.plan(screens, displays)[0], "portable-2")

    def test_focus_order_and_idempotence(self):
        screens = [monitor("DP-2", focused=True), monitor("DP-1", focused=False)]
        name, rules = module.plan(screens, displays)
        self.assertEqual((name, rules), module.plan(screens[::-1], displays))
        for rule in rules:
            m = next(m for m in screens if m["name"] == rule["name"])
            m.update({key: rule[key] for key in ("x", "y", "scale", "transform")})
        self.assertTrue(module.unchanged(screens, rules))

    def test_disabled_empty_invalid(self):
        self.assertEqual(module.plan([monitor("eDP-1", disabled=True)], displays)[1], [])
        self.assertEqual(module.plan([], displays)[1], [])
        with self.assertRaises(ValueError):
            module.plan([monitor("DP-1", scale=0)], displays)
        self.assertEqual(module.logical_width(1920, 1080, 1.5, 3), 720)

    def test_dry_run_only_reads_compositor(self):
        screens = [known("center", "DP-4"), known("left", "DP-5")]
        with patch.object(module, "hyprctl", return_value=json.dumps(screens)) as ipc:
            with contextlib.redirect_stdout(io.StringIO()) as output:
                module.reconcile(displays, dry_run=True)
        ipc.assert_called_once_with("monitors", "all", "-j")
        self.assertEqual(json.loads(output.getvalue())["profile"], "studio-pair")

    def test_reconcile_idempotent_and_reports_compositor_failure(self):
        screens = [monitor("DP-1")]
        with patch.object(module, "hyprctl", return_value=json.dumps(screens)) as ipc:
            module.reconcile(displays)
        ipc.assert_called_once_with("monitors", "all", "-j")
        screens[0]["x"] = 50
        with patch.object(module, "hyprctl", side_effect=[json.dumps(screens), "invalid mode"]):
            with self.assertRaises(RuntimeError):
                module.reconcile(displays)

    def test_watch_and_dry_run_cannot_be_combined(self):
        with patch.object(sys, "argv", ["monitor-layout", "--policy", "unused.json", "--watch", "--dry-run"]):
            with contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as error:
                    module.main()
        self.assertEqual(error.exception.code, 2)

    def test_event_stream_connects_before_first_plan_and_debounces(self):
        stream = unittest.mock.MagicMock()
        stream.__enter__.return_value = stream
        stream.recv.side_effect = [b"monitoradd", b"edv2>>1,DP-2,Generic\nmonitorremoved>>DP-1\n", b""]
        order = []
        stream.connect.side_effect = lambda path: order.append("connect")
        with patch.dict(module.os.environ, HYPRLAND_INSTANCE_SIGNATURE="test", XDG_RUNTIME_DIR="/runtime"):
            with patch.object(module.socket, "socket", return_value=stream):
                with patch.object(module.select, "select", side_effect=[([stream], [], []), ([stream], [], []), ([], [], []), ([stream], [], [])]):
                    with patch.object(module.time, "monotonic", return_value=100):
                        with patch.object(module, "reconcile", side_effect=lambda _: order.append("plan")):
                            module.watch(displays)
        self.assertEqual(order, ["connect", "plan", "plan"])

    def test_hyprctl_discards_only_inherited_library_path(self):
        with patch.dict(module.os.environ, LD_LIBRARY_PATH="/project/lib", MONITOR_TEST_ENV="preserved"):
            with patch.object(module.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "[]")) as run:
                self.assertEqual(module.hyprctl("monitors", "all", "-j"), "[]")
        self.assertNotIn("LD_LIBRARY_PATH", run.call_args.kwargs["env"])
        self.assertEqual(run.call_args.kwargs["env"]["MONITOR_TEST_ENV"], "preserved")
        self.assertEqual(run.call_args.kwargs["timeout"], 10)


unittest.main()
