#!/usr/bin/env python3
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPT, POLICY, TEMPLATES, REAL_CLI = sys.argv[1:5]
sys.argv = sys.argv[:1]
policy = json.loads(Path(POLICY).read_text())
spec = importlib.util.spec_from_file_location("appearance", SCRIPT)
appearance = importlib.util.module_from_spec(spec)
spec.loader.exec_module(appearance)


def contrast(first, second):
    def luminance(colour):
        channels = [int(colour[i:i + 2], 16) / 255 for i in (0, 2, 4)]
        channels = [value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4 for value in channels]
        return sum(weight * value for weight, value in zip((0.2126, 0.7152, 0.0722), channels))
    high, low = sorted((luminance(first), luminance(second)), reverse=True)
    return (high + 0.05) / (low + 0.05)


class AppearanceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.config = self.home / "config"
        self.state = self.home / "state/caelestia"
        self.shell = self.config / "caelestia/shell.json"
        self.shell.parent.mkdir(parents=True)
        shutil.copytree(TEMPLATES, self.shell.parent / "templates")
        self.bin = self.home / "bin"
        self.bin.mkdir()
        cli = self.bin / "caelestia"
        cli.write_text(f'''#!{sys.executable}
import importlib.util, json, os, pathlib, sys
state = pathlib.Path(os.environ['XDG_STATE_HOME']) / 'caelestia'
policy = json.loads(pathlib.Path({POLICY!r}).read_text())
mode = sys.argv[sys.argv.index('--mode') + 1]
(state / 'scheme.json').write_text(json.dumps({{'mode': mode, 'colours': policy['colours'][mode]}}))
if os.environ.get('TEST_THEME_FAIL'):
    (state / 'theme/kitty-colors.conf').write_text('partial theme')
    sys.exit(1)
if not os.environ.get('TEST_THEME_STALE'):
    spec = importlib.util.spec_from_file_location('appearance', {SCRIPT!r})
    appearance = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(appearance)
    templates = pathlib.Path(os.environ['XDG_CONFIG_HOME']) / 'caelestia/templates'
    for name in appearance.THEME_FILES:
        (state / 'theme' / name).write_bytes(appearance.render((templates / name).read_text(), policy['colours'][mode]))
''')
        cli.chmod(0o755)
        self.env = os.environ | {"HOME": str(self.home), "XDG_CONFIG_HOME": str(self.config), "XDG_STATE_HOME": str(self.home / "state"), "PATH": str(self.bin) + os.pathsep + os.environ["PATH"]}
        self.env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)

    def run_script(self, *args, success=True):
        result = subprocess.run([sys.executable, SCRIPT, "--policy", POLICY, *args], env=self.env, capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode == 0, success, result.stderr)

    def files(self):
        return {str(p.relative_to(self.home)): p.read_bytes() for p in self.home.rglob('*') if p.is_file() and 'backup' not in p.name and p.name != 'appearance.lock'}

    def test_preserves_nexus_choices_and_custom_actions(self):
        original = {"appearance": {"font": {"body": {"family": "My font"}}}, "paths": {"wallpaperDir": "/personal/pictures"}, "launcher": {"actions": [{"name": "My action", "command": ["echo", "hello"]}]}, "privateChoice": True}
        self.shell.write_text(json.dumps(original))
        self.run_script("bootstrap")
        result = json.loads(self.shell.read_text())
        self.assertEqual(result["appearance"]["font"]["body"]["family"], "My font")
        self.assertEqual(result["paths"], original["paths"])
        self.assertEqual(result["launcher"]["actions"][0], original["launcher"]["actions"][0])
        self.assertTrue(result["privateChoice"])
        self.assertEqual(self.shell.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.shell.with_name("shell.json.appearance-backup").stat().st_mode & 0o777, 0o600)

    def test_bootstrap_is_idempotent(self):
        self.run_script("bootstrap")
        before = self.files()
        mtimes = {p: p.stat().st_mtime_ns for p in self.state.rglob('*') if p.is_file() and p.name != 'appearance.lock'}
        self.run_script("bootstrap")
        self.assertEqual(self.files(), before)
        self.assertEqual({p: p.stat().st_mtime_ns for p in mtimes}, mtimes)

    def test_bootstrap_preserves_a_saved_native_scheme(self):
        # Native schemes have Material/terminal roles, without Catppuccin names.
        names = set(policy["colours"]["dark"])
        catppuccin_names = {"rosewater", "flamingo", "pink", "mauve", "red", "maroon", "peach", "yellow", "green", "teal", "sky", "sapphire", "blue", "lavender", "text", "subtext1", "subtext0", "overlay2", "overlay1", "overlay0", "surface2", "surface1", "surface0", "base", "mantle", "crust"}
        colours = {name: policy["colours"]["dark"][name] for name in names - catppuccin_names}
        scheme = {"name": "dracula", "flavour": "default", "mode": "dark", "variant": "tonalspot", "colours": colours}
        self.state.mkdir(parents=True)
        saved = self.state / "scheme.json"
        saved.write_text(json.dumps(scheme))
        before = saved.read_bytes()
        self.run_script("bootstrap")
        self.assertEqual(saved.read_bytes(), before)
        for name in appearance.THEME_FILES:
            self.assertNotIn("{{", (self.state / "theme" / name).read_text())

    def test_presets_preserve_unrelated_settings(self):
        self.shell.write_text(json.dumps({"nexus": {"networkRescanInterval": 12345}, "appearance": {"font": {"body": {"family": "Personal"}}}}))
        self.run_script("bootstrap")
        for preset in ("claro", "enfoque", "diario"):
            self.run_script("apply", preset)
            result = json.loads(self.shell.read_text())
            self.assertEqual(result["nexus"]["networkRescanInterval"], 12345)
            self.assertEqual(result["appearance"]["font"]["body"]["family"], "Personal")
            self.assertEqual(json.loads((self.state / "scheme.json").read_text())["mode"], policy["presets"][preset]["mode"])
        self.assertEqual(json.loads((self.state / "desktop-preset.json").read_text())["preset"], "diario")

    def test_real_cli_refreshes_saved_colours_and_switches_modes(self):
        self.run_script("bootstrap")
        cli = self.bin / "caelestia"
        cli.unlink()
        cli.symlink_to(REAL_CLI)
        # Only render user templates: isolate desktop side effects even in tests.
        flags = ("Term", "Hypr", "Discord", "Spicetify", "Pandora", "Fuzzel", "Btop", "Nvtop", "Htop", "Gtk", "Qt", "Warp", "Chromium", "Zed", "Cava")
        (self.shell.parent / "cli.json").write_text(json.dumps({"theme": {"enable" + name: False for name in flags}}))
        saved = self.state / "scheme.json"
        stale = json.loads(saved.read_text())
        stale["colours"]["primary"] = "111111"
        saved.write_text(json.dumps(stale))
        for preset in ("diario", "claro", "enfoque"):
            self.run_script("apply", preset)
            expected = policy["colours"][policy["presets"][preset]["mode"]]
            self.assertEqual(json.loads(saved.read_text())["colours"], expected)
        result = subprocess.run([str(cli), "scheme", "set", "--name", "dracula", "--flavour", "medium", "--mode", "dark"], env=self.env, capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stderr)
        before = saved.read_bytes()
        self.run_script("bootstrap")
        self.assertEqual(saved.read_bytes(), before)
        for name in appearance.THEME_FILES:
            self.assertNotIn("{{", (self.state / "theme" / name).read_text())

    def test_failed_theme_restores_shell_and_generated_state(self):
        self.run_script("bootstrap")
        before = self.files()
        self.env["TEST_THEME_FAIL"] = "1"
        self.run_script("apply", "claro", success=False)
        self.assertEqual(self.files(), before)

    def test_failed_compositor_reload_keeps_the_saved_preset(self):
        self.run_script("bootstrap")
        hyprctl = self.bin / "hyprctl"
        hyprctl.write_text("#!/bin/sh\nexit 1\n")
        hyprctl.chmod(0o755)
        self.env["HYPRLAND_INSTANCE_SIGNATURE"] = "unavailable-test-compositor"
        self.run_script("apply", "claro")
        self.assertEqual(json.loads((self.state / "desktop-preset.json").read_text())["preset"], "claro")

    def test_invalid_json_and_unknown_preset_fail_before_writes(self):
        self.run_script("bootstrap")
        before = self.files()
        self.run_script("apply", "unknown", success=False)
        self.assertEqual(self.files(), before)
        self.shell.write_text("broken json")
        before = self.files()
        self.run_script("bootstrap", success=False)
        self.assertEqual(self.files(), before)

    def test_success_exit_with_stale_templates_is_rejected(self):
        self.run_script("bootstrap")
        before = self.files()
        self.env["TEST_THEME_STALE"] = "1"
        self.run_script("apply", "claro", success=False)
        self.assertEqual(self.files(), before)

    def test_symlink_backup_rejected_before_writes(self):
        self.run_script("bootstrap")
        outside = self.home / "outside"
        outside.write_text("must stay")
        self.shell.with_name("shell.json.appearance-backup").symlink_to(outside)
        before = self.files()
        self.run_script("apply", "claro", success=False)
        self.assertEqual(self.files(), before)

    def test_semantic_colours_and_real_templates_in_both_modes(self):
        for mode, colours in policy["colours"].items():
            self.assertGreaterEqual(contrast(colours["surface"], colours["onSurface"]), 4.5, mode)
            self.assertGreaterEqual(contrast(colours["primary"], colours["onPrimary"]), 4.5, mode)
            for name in appearance.THEME_FILES:
                rendered = appearance.render((Path(TEMPLATES) / name).read_text(), colours).decode()
                self.assertNotIn("{{", rendered)
                self.assertIn(colours["primary"], rendered) if name != "starship.toml" else None


unittest.main()
