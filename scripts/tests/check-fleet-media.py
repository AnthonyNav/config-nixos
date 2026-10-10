#!/usr/bin/env python3
"""Media adapters and recording lifecycle with fake commands, never screen/audio."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import struct
import sys
import tempfile
import time
import unittest
from unittest.mock import patch


SOURCE = Path(sys.argv[1]).resolve()
spec = importlib.util.spec_from_file_location("fleet_media", SOURCE)
media = importlib.util.module_from_spec(spec)
spec.loader.exec_module(media)
sys.argv = sys.argv[:1]


class Media(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=Path(tempfile.gettempdir()).resolve())
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / "home"
        self.home.mkdir(mode=0o700)
        self.bin = Path(self.temp.name) / "bin"
        self.bin.mkdir()
        self.env = {**os.environ, "HOME": str(self.home), "PATH": str(self.bin) + os.pathsep + os.environ["PATH"]}
        self.fake("pactl", """import json,sys
if 'get-default-sink' in sys.argv: print('speaker')
elif 'get-default-source' in sys.argv: print('microphone')
elif 'sources' in sys.argv: print(json.dumps([{'name':'speaker.monitor','monitor_of_sink':7},{'name':'microphone','monitor_of_sink':None}]))
else: print(json.dumps([{'name':'speaker','index':7}]))
""")
        self.fake("hyprctl", """import json,sys
print(json.dumps([{'name':'DP-1','focused':True}] if 'monitors' in sys.argv else {'address':'0x1','mapped':True,'at':[-20,30],'size':[400,300]}))
""")
        self.fake("slurp", "print('-20,30 400x300')")
        self.fake("grim", """import sys,pathlib
data=b'\\x89PNG\\r\\n\\x1a\\n'+b'\\0\\0\\0\\rIHDR'+b'\\0\\0\\0\\1'*2+b'\\x08\\x06\\0\\0\\0'+b'\\0'*4
if sys.argv[-1]=='-':sys.stdout.buffer.write(data)
else:
 output=pathlib.Path(sys.argv[-1])
 replacement=output.with_name(output.name+'.replacement')
 replacement.write_bytes(data)
 replacement.replace(output)
""")
        self.fake("wl-copy", """import sys,pathlib,os
pathlib.Path(os.environ['HOME'],'clipboard').write_bytes(sys.stdin.buffer.read())
""")
        self.fake("wf-recorder", """import signal,time,sys,pathlib,os,json
def stop(*_):
 output=pathlib.Path(sys.argv[-1])
 replacement=output.with_name(output.name+'.replacement')
 replacement.write_bytes(b'finalized fake video')
 replacement.replace(output)
 sys.exit(0)
signal.signal(signal.SIGINT,stop)
pathlib.Path(os.environ['HOME'],'recorder-argv.json').write_text(json.dumps(sys.argv))
while True:time.sleep(.05)
""")
        self.fake("ffprobe", """import json,os
streams=[{'codec_type':'video','codec_name':'h264'}]
if not os.environ.get('FIXTURE_NO_AUDIO'):streams.append({'codec_type':'audio','codec_name':'aac'})
print(json.dumps({'streams':streams,'format':{'duration':'2.0'}}))
""")
        self.fake("ffmpeg", """import os,sys,struct
if os.environ.get('FIXTURE_UNDECODABLE'):sys.exit(1)
if 's16le' in sys.argv:sys.stdout.buffer.write(struct.pack('<h',0 if os.environ.get('FIXTURE_SILENT') else 512)*8000)
""")

    def fake(self, name, source):
        path = self.bin / name
        path.write_text(f"#!{sys.executable}\n" + source + "\n")
        path.chmod(0o755)

    def cli(self, *arguments, success=True):
        result = subprocess.run([sys.executable, "-B", str(SOURCE), "--platform", "linux", *arguments], env=self.env, capture_output=True, text=True, timeout=25, umask=0o022)
        value = json.loads(result.stdout)
        if success is None:
            self.assertIn(result.returncode, (0, 1), value)
        else:
            self.assertEqual(result.returncode, 0 if success else 1, value)
        self.assertEqual(result.stderr, "")
        return value

    def test_process_birth_and_uid_are_observed_from_kernel(self):
        identity = media.process_identity(os.getpid())
        self.assertIsNotNone(identity)
        self.assertEqual(identity["uid"], os.getuid())
        self.assertTrue(media.matches(identity))
        changed = dict(identity, start=["different birth"])
        self.assertFalse(media.matches(changed))
        self.assertFalse(media.matches(dict(identity, uid=os.getuid() + 1)))
        self.assertTrue(media.same_birth(dict(identity, executable='before-exec')))
        self.assertFalse(media.same_birth(changed))
        self.assertFalse(media.same_birth(dict(identity, uid=os.getuid() + 1)))

    def test_area_clipboard_and_explicit_file_use_exact_arguments(self):
        value = self.cli("screenshot", "area", "--region=-20,30,400,300", "--clipboard")
        self.assertEqual(value, {"status": "captured", "destination": "clipboard"})
        self.assertTrue((self.home / "clipboard").read_bytes().startswith(b"\x89PNG"))
        destination = self.home / "image;$(false).png"
        self.cli("screenshot", "window", "--file", str(destination))
        self.assertTrue(destination.is_file())
        self.assertEqual(destination.stat().st_mode & 0o777, 0o600)

    def test_backend_explicitly_unsafe_permissions_are_rejected(self):
        self.fake("grim", """import pathlib,sys
output=pathlib.Path(sys.argv[-1])
output.write_bytes(b'unsafe capture')
output.chmod(0o644)
""")
        destination = self.home / "unsafe.png"
        result = self.cli("screenshot", "screen", "--file", str(destination), success=False)
        self.assertIn("unsafe ownership, links or permissions", result["error"])
        self.assertFalse(destination.exists())

    def test_cancel_preserves_clipboard_and_creates_no_file(self):
        clipboard = self.home / "clipboard"
        clipboard.write_bytes(b"previous")
        self.fake("slurp", "import sys;sys.exit(1)")
        self.cli("screenshot", "area", "--clipboard", success=False)
        self.assertEqual(clipboard.read_bytes(), b"previous")
        self.assertFalse((self.home / "Pictures").exists())

    def test_failed_capture_does_not_clear_clipboard(self):
        clipboard = self.home / "clipboard"
        clipboard.write_bytes(b"previous")
        self.fake("grim", "import sys;sys.exit(1)")
        self.cli("screenshot", "area", "--region=1,2,3,4", success=False)
        self.assertEqual(clipboard.read_bytes(), b"previous")

    def test_region_and_destinations_reject_unsafe_values(self):
        for value in ("0,0,0,4", "0,0,3,0", "0,0,3,4;false", "0,0,3,-1"):
            self.cli("screenshot", "area", "--region=" + value, success=False)
        target = self.home / "target"
        target.mkdir()
        (self.home / "link").symlink_to(target, target_is_directory=True)
        self.cli("screenshot", "screen", "--file", str(self.home / "link/image.png"), success=False)
        self.assertFalse((target / "image.png").exists())
        self.cli("screenshot", "screen", "--file", str(self.home / "shared/image.png"), success=False)

    def test_media_state_rejects_symlink_and_shared_permissions(self):
        state = media.State(self.home)
        self.addCleanup(state.close)
        outside = self.home / "outside"
        outside.write_text('{}')
        outside.chmod(0o600)
        (state.path / "record.json").symlink_to(outside)
        with self.assertRaises(OSError):
            state.read()
        with self.assertRaises(OSError):
            state.write({"status": "idle"})
        self.assertEqual(outside.read_text(), '{}')
        (state.path / "record.json").unlink()
        (state.path / "lock").write_text('')
        (state.path / "lock").chmod(0o644)
        with self.assertRaises(media.MediaError):
            with state.lock():
                pass

    def test_start_stop_default_audio_and_duplicate_start(self):
        self.assertEqual(self.cli("record", "status"), {"status": "idle"})
        self.assertEqual(self.cli("record", "stop"), {"status": "idle"})
        started = self.cli("record", "start", "--target", "area", "--region=1,2,30,40")
        try:
            self.assertEqual(started["status"], "recording")
            self.assertEqual(started["audio"], "system")
            self.assertIn("--audio=speaker.monitor", json.loads((self.home / "recorder-argv.json").read_text()))
            self.cli("record", "start", "--target", "area", "--region=1,2,30,40", success=False)
        finally:
            finished = self.cli("record", "stop")
        self.assertEqual(finished["status"], "finished")
        self.assertEqual(Path(finished['path']).parent, self.home / 'Movies/ScreenRecordings')
        self.assertEqual(Path(finished["path"]).read_bytes(), b"finalized fake video")
        self.assertEqual(Path(finished["path"]).stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.cli("record", "stop"), finished)
        self.assertEqual(self.cli("record", "status"), finished)
        state = media.State(self.home)
        try:
            self.assertNotIn("command", state.read())
        finally:
            state.close()

    def test_darwin_recorder_requires_absent_private_staging_destination(self):
        recorder = (self.bin / "wf-recorder").read_text()
        self.fake("wf-recorder", "import pathlib,sys\nif pathlib.Path(sys.argv[-1]).exists(): sys.exit(3)\nif pathlib.Path(sys.argv[-1]).parent.stat().st_mode & 0o777 != 0o700: sys.exit(4)\n" + recorder.split("\n", 1)[1])
        verify = media.verify_video
        for change in (None, 'content', 'inode', 'permissions-before'):
            with self.subTest(destination_change=change):
                destination = media.reserve_output(self.home, "record")
                if change == 'permissions-before':
                    Path(destination).chmod(0o644)
                (self.home / 'recorder-argv.json').unlink(missing_ok=True)
                session = 'fixture-native-video'
                state = media.State(self.home)
                self.addCleanup(state.close)
                with state.lock():
                    state.write({'session':session, 'status':'starting', 'platform':'darwin',
                                 'command':[str(self.bin / 'wf-recorder')], 'path':destination,
                                 'audio':'none', 'stop_requested':False})
                def finalized(path, audio):
                    verify(path, audio)
                    if change == 'content':
                        Path(destination).write_bytes(b'user content')
                    elif change == 'inode':
                        replacement = Path(destination).with_suffix('.replacement')
                        replacement.write_bytes(b'')
                        replacement.chmod(0o600)
                        replacement.replace(destination)
                with patch.dict(os.environ, self.env, clear=True), patch.object(media, 'verify_video', side_effect=finalized), ThreadPoolExecutor(max_workers=1) as executor:
                    running = executor.submit(media.worker, 'darwin', session, self.home)
                    # Request stop after the fixture has installed its signal handler.
                    # Native cancellation before startup can legitimately produce no frames.
                    deadline = time.monotonic() + 5
                    try:
                        while not (self.home / 'recorder-argv.json').exists() and not running.done() and time.monotonic() < deadline:
                            time.sleep(0.01)
                    finally:
                        with state.lock():
                            value = state.read()
                            value['stop_requested'] = True
                            state.write(value)
                    self.assertEqual(running.result(timeout=15), 1 if change else 0, state.read())
                if change:
                    self.assertEqual(state.read()['status'], 'failed')
                    self.assertIn('unsafe ownership' if change == 'permissions-before' else 'destination changed', state.read()['error'])
                else:
                    self.assertEqual(state.read()['status'], 'finished')
                self.assertEqual(Path(destination).read_bytes(), b'user content' if change == 'content' else b'' if change else b'finalized fake video')
                self.assertEqual(Path(destination).stat().st_mode & 0o777, 0o644 if change == 'permissions-before' else 0o600)
                if change == 'permissions-before':
                    self.assertFalse((self.home / 'recorder-argv.json').exists())
                    continue
                staging = Path(json.loads((self.home / 'recorder-argv.json').read_text())[-1])
                self.assertNotEqual(str(staging), destination)
                self.assertEqual(staging.parent.parent, Path(destination).parent)
                self.assertFalse(staging.parent.exists())
                self.assertFalse(any(Path(destination).parent.glob('.fleet-record-*')))

    def test_default_output_without_monitor_fails_before_start(self):
        self.fake("pactl", """import json,sys
if 'get-default-sink' in sys.argv:print('speaker')
elif 'sources' in sys.argv:print(json.dumps([{'name':'microphone','monitor_of_sink':None}]))
else:print(json.dumps([{'name':'speaker','index':7}]))
""")
        value = self.cli("record", "start", "--target", "area", "--region=1,2,30,40", success=False)
        self.assertIn("refusing silent fallback", value["error"])
        self.assertFalse((self.home / "recorder-argv.json").exists())
        self.assertFalse((self.home / "Movies").exists())

    def test_missing_audio_track_cannot_be_success(self):
        self.env["FIXTURE_NO_AUDIO"] = "1"
        self.cli("record", "start", "--target", "area", "--region=1,2,30,40")
        result = self.cli("record", "stop", success=False)
        self.assertEqual(result["status"], "failed")
        self.assertIn("no audio track", result["error"])

    def test_recorder_refusal_surfaces_without_stale_active_session(self):
        self.fake("wf-recorder", "import sys;sys.exit(3)")
        # A cold interpreter may exit after the startup observation window.
        # Refusal must still converge to failure without a stale active session.
        started = self.cli("record", "start", "--target", "area", "--region=1,2,30,40", success=None)
        self.assertIn(started["status"], ("error", "recording"))
        deadline = time.monotonic() + 5
        current = self.cli("record", "status")
        while current["status"] in ("starting", "recording", "finalizing") and time.monotonic() < deadline:
            time.sleep(0.05)
            current = self.cli("record", "status")
        self.assertEqual(current["status"], "failed")
        self.assertEqual(self.cli("record", "stop", success=False)["status"], "failed")

    def test_stale_supervisor_never_signals_reused_pid(self):
        state = media.State(self.home)
        try:
            identity = dict(media.process_identity(os.getpid()), start=["old birth"])
            with state.lock():
                state.write({"status": "recording", "supervisor": identity, "recorder": identity, "session": "old"})
            args = argparse.Namespace(operation="stop")
            with patch.object(os, "kill", side_effect=AssertionError("must not signal unrelated PID")):
                value = media.status_or_stop(args, self.home)
            self.assertEqual(value["status"], "failed")
        finally:
            state.close()

    def test_darwin_native_flags_and_certificate_gate_without_capture(self):
        args = argparse.Namespace(platform="darwin", target="area", region="1,2,30,40", audio="system", file="auto", monitor="focused")
        self.assertEqual(media.recorder_command(args), ["/usr/sbin/screencapture", "-v", "-R", "1,2,30,40", "-A"])
        args.audio = "microphone"
        self.assertEqual(media.recorder_command(args)[-1], "-g")
        args.audio = "none"
        self.assertNotIn("-g", media.recorder_command(args))
        args.region = None
        args.audio = "system"
        self.assertEqual(media.recorder_command(args), ["/usr/sbin/screencapture", "-v", "-i", "-s", "-A"])
        with patch.object(media, "certificate", return_value={"os_build": "fixture"}), patch.object(media, "recorder_command", side_effect=AssertionError("unverified Mac must not record")):
            with self.assertRaisesRegex(media.MediaError, "not verified"):
                media.start(args, self.home)

    def test_probe_missing_audio_never_certifies(self):
        args = argparse.Namespace(platform="darwin", region="1,2,30,40", seconds=1)
        def fake_start(args, *_unused, **_keywords):
            args.created_session = 'fixture'
            return {'status': 'recording'}
        with patch.object(media, "certificate", return_value={"os_build": "fixture"}), patch.object(media, "start", side_effect=fake_start), patch.object(time, "sleep"), patch.object(media, "status_or_stop", return_value={"status": "failed", "error": "no audio track"}):
            with self.assertRaisesRegex(media.MediaError, "no audio track"):
                media.probe(args, self.home)
        self.assertFalse((self.home / ".local/state/fleet/media/darwin-verified.json").exists())

    def test_probe_failure_invalidates_previous_certificate(self):
        state = media.State(self.home)
        try:
            with state.lock():
                state.write({"os_build": "fixture"}, "darwin-verified.json")
        finally:
            state.close()
        self.test_probe_missing_audio_never_certifies()

    def test_audio_none_is_explicit_and_microphone_is_opt_in(self):
        for mode in ("none", "microphone"):
            self.cli("record", "start", "--target", "area", "--region=1,2,30,40", "--audio", mode)
            try:
                argv = json.loads((self.home / "recorder-argv.json").read_text())
                audio = [arg for arg in argv if arg.startswith('--audio=')]
                self.assertEqual(audio, [] if mode == "none" else ["--audio=microphone"])
            finally:
                self.cli("record", "stop")

    def test_empty_video_is_cancelled_and_not_marked_finished(self):
        self.fake("wf-recorder", """import signal,time,sys
signal.signal(signal.SIGINT,lambda *_:sys.exit(0))
while True:time.sleep(.05)
""")
        started = self.cli("record", "start", "--target", "area", "--region=1,2,30,40")
        stopped = self.cli("record", "stop", success=False)
        self.assertIn('cancelled or refused', stopped['error'])
        self.assertFalse(Path(started['path']).exists())

    def test_probe_interruption_requests_stop_only_for_owned_session(self):
        args = argparse.Namespace(platform='darwin', region='1,2,30,40', seconds=1)
        def fake_start(args, *_unused, **_keywords):
            args.created_session = 'fixture-owned-session'
        with patch.object(media, 'certificate', return_value={'os_build': 'fixture'}), patch.object(media, 'start', side_effect=fake_start), patch.object(time, 'sleep', side_effect=KeyboardInterrupt), patch.object(media, 'status_or_stop', return_value={'status': 'finished'}) as stop:
            with self.assertRaises(KeyboardInterrupt):
                media.probe(args, self.home)
            stop.assert_called_once()
            self.assertEqual(args.expected_session, 'fixture-owned-session')

    def test_probe_conflict_does_not_stop_an_existing_recording(self):
        args = argparse.Namespace(platform='darwin', region='1,2,30,40', seconds=1)
        with patch.object(media, 'certificate', return_value={'os_build': 'fixture'}), patch.object(media, 'start', side_effect=media.MediaError('already active')), patch.object(media, 'status_or_stop') as stop:
            with self.assertRaisesRegex(media.MediaError, 'already active'):
                media.probe(args, self.home)
            stop.assert_not_called()

    def test_mac_clipboard_escape_never_copies_or_claims_capture(self):
        args = argparse.Namespace(platform='darwin', target='area', region=None, file=None, monitor='focused', window_id=None)
        with patch.object(media, 'checked_run') as capture, patch.object(media, 'darwin_clipboard') as copy:
            with self.assertRaisesRegex(media.MediaError, 'cancelled or invalid'):
                media.screenshot(args, self.home)
            argv = capture.call_args.args[0]
            self.assertEqual(argv[:4], ['/usr/sbin/screencapture', '-x', '-i', '-s'])
            self.assertNotIn('-c', argv)
            copy.assert_not_called()
            self.assertFalse(Path(argv[-1]).exists())

    def test_mac_clipboard_uses_private_validated_png_then_removes_it(self):
        args = argparse.Namespace(platform='darwin', target='area', region='1,2,30,40', file=None, monitor='focused', window_id=None)
        original_run = subprocess.run
        def capture(argv, **kwargs):
            self.assertEqual(argv[0], '/usr/sbin/screencapture')
            return original_run([str(self.bin / 'grim'), *argv[1:]], env=self.env, **kwargs)
        paths = []
        def copy(path):
            paths.append(path)
            self.assertEqual(Path(path).stat().st_mode & 0o777, 0o600)
            media.verify_png(path)
        caller_umask = os.umask(0o022)
        try:
            with patch.object(subprocess, 'run', side_effect=capture), patch.object(media, 'darwin_clipboard', side_effect=copy):
                self.assertEqual(media.screenshot(args, self.home), {'status':'captured','destination':'clipboard'})
        finally:
            os.umask(caller_umask)
        self.assertEqual(len(paths), 1)
        self.assertFalse(Path(paths[0]).exists())

    def fake_finished_probe(self):
        args = argparse.Namespace(platform='darwin', region='1,2,30,40', seconds=1)
        path = media.reserve_output(self.home, 'record')
        Path(path).write_bytes(b'fixture')
        def start(args, *_unused, **_keywords):
            args.created_session = 'owned-fixture'
        with patch.dict(os.environ, self.env, clear=True), patch.object(media, 'certificate', return_value={'os_build':'fixture'}), patch.object(media, 'start', side_effect=start), patch.object(media, 'status_or_stop', return_value={'status':'finished','audio':'system','path':path}), patch.object(time, 'sleep'):
            return media.probe(args, self.home)

    def test_probe_requires_decodable_video_and_non_silent_system_audio(self):
        result = self.fake_finished_probe()
        self.assertTrue(result['verified'])
        marker = self.home / '.local/state/fleet/media/darwin-verified.json'
        self.assertTrue(marker.is_file())
        self.env['FIXTURE_SILENT'] = '1'
        with self.assertRaisesRegex(media.MediaError, 'audio was silent'):
            self.fake_finished_probe()
        self.assertFalse(marker.exists())
        self.env.pop('FIXTURE_SILENT')
        self.env['FIXTURE_UNDECODABLE'] = '1'
        with self.assertRaisesRegex(media.MediaError, 'could not be decoded'):
            self.fake_finished_probe()
        self.assertFalse(marker.exists())

    def test_clipboard_path_is_an_argument_to_fixed_jxa(self):
        path = str(self.home / "quote'and;$(false).png")
        with patch.object(subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)) as invoked:
            media.darwin_clipboard(path)
        argv = invoked.call_args.args[0]
        self.assertEqual(argv[-2:], ['--', path])
        self.assertNotIn(path, argv[4])

    def test_stop_timeout_preserves_pending_session_without_signalling_pid(self):
        state = media.State(self.home)
        try:
            with state.lock():
                state.write({'status':'recording','session':'fixture','supervisor':media.process_identity(os.getpid()),'audio':'system'})
            args = argparse.Namespace(operation='stop')
            with patch.object(time, 'monotonic', side_effect=[0, 100]), patch.object(os, 'kill', side_effect=AssertionError('must not signal stored PID')):
                result = media.status_or_stop(args, self.home)
            self.assertEqual(result['status'], 'recording')
            self.assertIn('pending', result['error'])
            self.assertTrue(state.read()['stop_requested'])
            self.assertEqual(state.read()['session'], 'fixture')
        finally:
            state.close()


unittest.main()
