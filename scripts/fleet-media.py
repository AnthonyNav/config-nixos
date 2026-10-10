#!/usr/bin/env python3
"""Local media actions; callers select the platform, never an account or shell."""
import argparse
import contextlib
import ctypes
import fcntl
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import signal
import stat
import struct
import subprocess
import sys
import time
import uuid


class MediaError(Exception):
    pass


def command(name):
    path = shutil.which(name)
    if not path:
        raise MediaError(f"Required media command is unavailable: {name}")
    return str(Path(path).resolve())


def run_json(argv):
    result = subprocess.run(argv, capture_output=True, text=True, timeout=10)
    if result.returncode:
        raise MediaError(f"Media discovery failed: {Path(argv[0]).name}")
    try:
        return json.loads(result.stdout)
    except ValueError as error:
        raise MediaError("Media discovery returned invalid JSON") from error


def checked_run(argv):
    result = subprocess.run(argv, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if result.returncode:
        raise MediaError("Capture failed or was cancelled; check capture permissions and selected target")


def region(value):
    if not re.fullmatch(r"-?\d+,-?\d+,\d+,\d+", value):
        raise MediaError("Region must be x,y,width,height, with positive dimensions")
    values = tuple(int(part) for part in value.split(","))
    if values[2] <= 0 or values[3] <= 0 or any(abs(v) > 100000 for v in values):
        raise MediaError("Region dimensions are invalid")
    return values


def grim_region(rect):
    x, y, width, height = rect
    return f"{x},{y} {width}x{height}"


def selected_region():
    result = subprocess.run([command("slurp")], capture_output=True, text=True)
    if result.returncode or not result.stdout.strip():
        raise MediaError("Area selection cancelled")
    match = re.fullmatch(r"(-?\d+),(-?\d+) (\d+)x(\d+)", result.stdout.strip())
    if not match:
        raise MediaError("Area selector returned invalid geometry")
    return region(",".join(match.groups()))


def linux_monitor(name):
    monitors = run_json([command("hyprctl"), "-j", "monitors"])
    candidates = [m for m in monitors if m.get("focused")] if name == "focused" else [m for m in monitors if m.get("name") == name]
    if len(candidates) != 1 or not isinstance(candidates[0].get("name"), str):
        raise MediaError("Requested Wayland monitor is unavailable")
    return candidates[0]["name"]


def linux_window():
    value = run_json([command("hyprctl"), "-j", "activewindow"])
    if not value.get("address") or not value.get("mapped", True):
        raise MediaError("No active Wayland window")
    try:
        return region(",".join(str(n) for n in [*value["at"], *value["size"]]))
    except (KeyError, TypeError) as error:
        raise MediaError("Active window has no usable geometry") from error


class Rect(ctypes.Structure):
    _fields_ = [(name, ctypes.c_double) for name in ("x", "y", "width", "height")]


def darwin_targets():
    """Read native window/display geometry, without capturing pixels or titles."""
    cg = ctypes.CDLL("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics")
    cf = ctypes.CDLL("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
    cg.CGWindowListCopyWindowInfo.argtypes = [ctypes.c_uint32, ctypes.c_uint32]
    cg.CGWindowListCopyWindowInfo.restype = ctypes.c_void_p
    cf.CFPropertyListCreateData.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_long, ctypes.c_ulong, ctypes.c_void_p]
    cf.CFPropertyListCreateData.restype = ctypes.c_void_p
    cf.CFDataGetLength.argtypes = [ctypes.c_void_p]
    cf.CFDataGetLength.restype = ctypes.c_long
    cf.CFDataGetBytePtr.argtypes = [ctypes.c_void_p]
    cf.CFDataGetBytePtr.restype = ctypes.c_void_p
    cf.CFRelease.argtypes = [ctypes.c_void_p]
    windows = cg.CGWindowListCopyWindowInfo(1, 0)
    if not windows:
        raise MediaError("Native window discovery failed; check Screen Recording permission")
    data = None
    try:
        data = cf.CFPropertyListCreateData(None, windows, 200, 0, None)
        if not data:
            raise MediaError("Native window discovery returned invalid metadata")
        values = plistlib.loads(ctypes.string_at(cf.CFDataGetBytePtr(data), cf.CFDataGetLength(data)))
    finally:
        if data:
            cf.CFRelease(data)
        cf.CFRelease(windows)
    # CoreGraphics supplies front-to-back order. Do not persist window titles.
    windows = [v for v in values if v.get("kCGWindowLayer") == 0 and v.get("kCGWindowBounds", {}).get("Width", 0) > 0]
    ids = (ctypes.c_uint32 * 32)()
    count = ctypes.c_uint32()
    cg.CGGetActiveDisplayList.argtypes = [ctypes.c_uint32, ctypes.POINTER(ctypes.c_uint32), ctypes.POINTER(ctypes.c_uint32)]
    if cg.CGGetActiveDisplayList(32, ids, ctypes.byref(count)) != 0:
        raise MediaError("Native display discovery failed")
    cg.CGDisplayBounds.argtypes = [ctypes.c_uint32]
    cg.CGDisplayBounds.restype = Rect
    displays = [cg.CGDisplayBounds(ids[i]) for i in range(count.value)]
    return windows, displays


def darwin_rect(bounds):
    return region(",".join(str(round(bounds[key])) for key in ("X", "Y", "Width", "Height")))


def darwin_window(window_id=None):
    windows, _ = darwin_targets()
    if window_id is not None:
        windows = [w for w in windows if w.get("kCGWindowNumber") == window_id]
    if not windows:
        raise MediaError("No visible target window")
    value = windows[0]
    return int(value["kCGWindowNumber"]), darwin_rect(value["kCGWindowBounds"])


def darwin_monitor(name):
    if name != "focused":
        raise MediaError("Darwin monitor selection currently supports 'focused' only")
    windows, displays = darwin_targets()
    if not windows or not displays:
        raise MediaError("No frontmost window/display; select an explicit region")
    wx, wy, ww, wh = darwin_rect(windows[0]["kCGWindowBounds"])
    def overlap(display):
        return max(0, min(wx + ww, display.x + display.width) - max(wx, display.x)) * max(0, min(wy + wh, display.y + display.height) - max(wy, display.y))
    selected = max(displays, key=overlap)
    if overlap(selected) <= 0:
        raise MediaError("Frontmost window is not on an active display")
    return region(",".join(str(round(getattr(selected, key))) for key in ("x", "y", "width", "height")))


def linux_audio(mode):
    if mode == "none":
        return None
    pactl = command("pactl")
    operation = "get-default-sink" if mode == "system" else "get-default-source"
    result = subprocess.run([pactl, operation], capture_output=True, text=True, timeout=10)
    selected = result.stdout.strip()
    if result.returncode or not selected:
        raise MediaError(f"No default {mode} audio device; refusing silent fallback")
    sources = run_json([pactl, "--format=json", "list", "sources"])
    if mode == "system":
        sinks = run_json([pactl, "--format=json", "list", "sinks"])
        sink = next((v for v in sinks if v.get("name") == selected), None)
        if not sink:
            raise MediaError("Default output has no corresponding audio sink")
        index, monitor_name = sink.get("index"), sink.get("monitor_source_name")
        candidates = [v for v in sources if (index is not None and v.get("monitor_of_sink") in (index, selected)) or (monitor_name and v.get("name") == monitor_name)]
    else:
        candidates = [v for v in sources if v.get("name") == selected and v.get("monitor_of_sink") in (None, "", 4294967295)]
    if len(candidates) != 1 or not candidates[0].get("name"):
        raise MediaError(f"No verified {mode} audio source; refusing silent fallback")
    return candidates[0]["name"]


def directory(path, private=False):
    """Walk with O_NOFOLLOW so mutable output/state never traverses symlinks."""
    path = Path(os.path.abspath(path))
    descriptor = os.open(path.anchor, os.O_RDONLY | os.O_DIRECTORY)
    try:
        for part in path.parts[1:]:
            try:
                os.mkdir(part, 0o700, dir_fd=descriptor)
            except FileExistsError:
                pass
            child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=descriptor)
            os.close(descriptor)
            descriptor = child
        metadata = os.fstat(descriptor)
        if metadata.st_uid != os.getuid() or (private and stat.S_IMODE(metadata.st_mode) != 0o700):
            raise MediaError("Media directory has unsafe ownership or permissions")
        return descriptor
    except Exception:
        os.close(descriptor)
        raise


def private_file(descriptor, name, flags):
    fd = os.open(name, flags | os.O_NOFOLLOW, 0o600, dir_fd=descriptor)
    metadata = os.fstat(fd)
    if not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != os.getuid() or metadata.st_nlink != 1 or stat.S_IMODE(metadata.st_mode) != 0o600:
        os.close(fd)
        raise MediaError("Media state file has unsafe ownership, links or permissions")
    return fd


class State:
    def __init__(self, home):
        self.path = Path(home) / ".local/state/fleet/media"
        self.fd = directory(self.path, private=True)

    def close(self):
        os.close(self.fd)

    @contextlib.contextmanager
    def lock(self):
        fd = private_file(self.fd, "lock", os.O_RDWR | os.O_CREAT)
        try:
            fcntl.flock(fd, fcntl.LOCK_EX)
            yield
        finally:
            os.close(fd)

    def read(self, name="record.json"):
        try:
            fd = private_file(self.fd, name, os.O_RDONLY)
        except FileNotFoundError:
            return None
        with os.fdopen(fd) as handle:
            value = json.load(handle)
        if not isinstance(value, dict):
            raise MediaError("Invalid media state")
        return value

    def write(self, value, name="record.json"):
        # Reject an existing malicious link before atomic replacement.
        self.read(name)
        temporary = f".{uuid.uuid4().hex}.tmp"
        fd = private_file(self.fd, temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL)
        try:
            with os.fdopen(fd, "w") as handle:
                json.dump(value, handle)
                handle.write("\n")
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary, name, src_dir_fd=self.fd, dst_dir_fd=self.fd)
        finally:
            with contextlib.suppress(FileNotFoundError):
                os.unlink(temporary, dir_fd=self.fd)

    def remove(self, name):
        if self.read(name) is not None:
            os.unlink(name, dir_fd=self.fd)


class BSDInfo(ctypes.Structure):
    _fields_ = [(name, ctypes.c_uint32) for name in ("flags", "status", "xstatus", "pid", "ppid", "uid", "gid", "ruid", "rgid", "svuid", "svgid", "reserved")] + [("comm", ctypes.c_char * 16), ("name", ctypes.c_char * 32)] + [(name, ctypes.c_uint32) for name in ("nfiles", "pgid", "pjobc", "tdev", "tpgid")] + [("nice", ctypes.c_int32), ("startsec", ctypes.c_uint64), ("startusec", ctypes.c_uint64)]


def process_identity(pid):
    """Use the real host kernel, even when adapters are tested with fake commands."""
    try:
        if sys.platform == "darwin":
            library = ctypes.CDLL("/usr/lib/libproc.dylib")
            info = BSDInfo()
            library.proc_pidinfo.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_uint64, ctypes.c_void_p, ctypes.c_int]
            if library.proc_pidinfo(pid, 3, 0, ctypes.byref(info), ctypes.sizeof(info)) != ctypes.sizeof(info) or info.status == 5:
                return None
            buffer = ctypes.create_string_buffer(4096)
            library.proc_pidpath.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_uint32]
            if library.proc_pidpath(pid, buffer, len(buffer)) <= 0:
                return None
            return {"pid": pid, "uid": int(info.uid), "start": [int(info.startsec), int(info.startusec)], "executable": buffer.value.decode()}
        base = Path(f"/proc/{pid}")
        fields = (base / "stat").read_text().rsplit(")", 1)[1].split()
        if fields[0] == "Z":
            return None
        return {"pid": pid, "uid": base.stat().st_uid, "start": [Path("/proc/sys/kernel/random/boot_id").read_text().strip(), fields[19]], "executable": os.readlink(base / "exe")}
    except (OSError, ValueError, IndexError):
        return None


def matches(identity):
    return bool(identity and identity.get("uid") == os.getuid() and process_identity(identity.get("pid", -1)) == identity)


def same_birth(identity):
    # A recorder may exec another interpreter/backend. Its birth and UID remain
    # stable; our unreaped Popen child also prevents PID reuse during signaling.
    current = process_identity(identity.get("pid", -1)) if identity else None
    return bool(current and current.get("uid") == os.getuid() and all(current.get(key) == identity.get(key) for key in ("pid", "uid", "start")))


def reserve_output(home, kind, value="auto"):
    base = Path(home) / ("Pictures/Screenshots" if kind == "screenshot" else "Movies/ScreenRecordings")
    extension = ".png" if kind == "screenshot" else ".mp4"
    path = base / (time.strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:8] + extension) if value == "auto" else Path(value).expanduser()
    path = Path(os.path.abspath(path))
    home_path = Path(os.path.abspath(home))
    if not path.is_relative_to(home_path) or "shared" in path.relative_to(home_path).parts:
        raise MediaError("Media output must be a local path under home, outside shared directories")
    fd = directory(path.parent)
    try:
        output = private_file(fd, path.name, os.O_WRONLY | os.O_CREAT | os.O_EXCL)
        os.close(output)
    finally:
        os.close(fd)
    return str(path)


def verify_png(path):
    fd = directory(Path(path).parent)
    try:
        handle = private_file(fd, Path(path).name, os.O_RDONLY)
        with os.fdopen(handle, "rb") as image:
            header = image.read(33)
        if len(header) < 33 or not header.startswith(b"\x89PNG\r\n\x1a\n") or header[12:16] != b"IHDR" or 0 in struct.unpack(">II", header[16:24]):
            raise MediaError("Capture cancelled or invalid; clipboard was preserved")
    finally:
        os.close(fd)


def darwin_clipboard(path):
    # This fixed program receives a separate path argument; no user text is code.
    program = """ObjC.import('AppKit'); ObjC.import('Foundation');
function run(argv) {
  const image = $.NSData.dataWithContentsOfFile($(argv[0]));
  if (!image || image.length < 33) throw Error('No complete image');
  const board = $.NSPasteboard.generalPasteboard;
  board.clearContents;
  if (!board.setDataForType(image, $('public.png'))) throw Error('Clipboard unavailable');
}"""
    result = subprocess.run(["/usr/bin/osascript", "-l", "JavaScript", "-e", program, "--", path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if result.returncode:
        raise MediaError("Screenshot was captured but could not be copied to clipboard")


def screenshot(args, home):
    rect = region(args.region) if args.region else None
    if rect and args.target != "area":
        raise MediaError("--region is only valid for an area capture")
    argv = [command("grim")] if args.platform == "linux" else ["/usr/sbin/screencapture", "-x"]
    if args.platform == "linux":
        if args.target == "area":
            rect = rect or selected_region()
        elif args.target == "window":
            rect = linux_window()
        else:
            argv.extend(["-o", linux_monitor(args.monitor)])
        if rect:
            argv.extend(["-g", grim_region(rect)])
    elif args.target == "area":
        argv.extend(["-R", ",".join(map(str, rect))] if rect else ["-i", "-s"])
    elif args.target == "window":
        window_id, _ = darwin_window(args.window_id)
        argv.extend(["-l", str(window_id), "-o"])
    else:
        argv.extend(["-R", ",".join(map(str, darwin_monitor(args.monitor)))])
    if args.file is None:
        if args.platform == "darwin":
            state = State(home)
            try:
                path = str(state.path / ("clipboard-" + uuid.uuid4().hex + ".png"))
                output = private_file(state.fd, Path(path).name, os.O_WRONLY | os.O_CREAT | os.O_EXCL)
                os.close(output)
                try:
                    checked_run([*argv, "-t", "png", path])
                    verify_png(path)
                    darwin_clipboard(path)
                finally:
                    with contextlib.suppress(FileNotFoundError):
                        os.unlink(Path(path).name, dir_fd=state.fd)
            finally:
                state.close()
        else:
            # Produce a complete image first: cancellation/failure must not erase clipboard.
            result = subprocess.run([*argv, "-"], capture_output=True)
            if result.returncode or not result.stdout.startswith(b"\x89PNG\r\n\x1a\n"):
                raise MediaError("Screenshot failed; clipboard was preserved")
            subprocess.run([command("wl-copy"), "--type", "image/png"], input=result.stdout, check=True)
        return {"status": "captured", "destination": "clipboard"}
    path = reserve_output(home, "screenshot", args.file)
    try:
        checked_run([*argv, path])
        verify_png(path)
    except Exception:
        with contextlib.suppress(FileNotFoundError):
            Path(path).unlink()
        raise
    return {"status": "captured", "path": path}


def certificate():
    executable = Path("/usr/sbin/screencapture")
    return {"schema": 1, "uid": os.getuid(), "executable": str(executable), "sha256": hashlib.sha256(executable.read_bytes()).hexdigest(), "os_build": subprocess.check_output(["/usr/bin/sw_vers", "-buildVersion"], text=True).strip()}


def verify_video(path, audio):
    fd = directory(Path(path).parent)
    try:
        handle = private_file(fd, Path(path).name, os.O_RDONLY)
        try:
            if os.fstat(handle).st_size == 0:
                raise MediaError("Recording cancelled or refused; no frames produced")
        finally:
            os.close(handle)
    finally:
        os.close(fd)
    value = run_json([command("ffprobe"), "-v", "error", "-show_streams", "-show_format", "-of", "json", path])
    streams = value.get("streams", [])
    if not any(s.get("codec_type") == "video" and s.get("codec_name") for s in streams) or float(value.get("format", {}).get("duration", 0)) <= 0:
        raise MediaError("Recorder did not finalize a playable video")
    if audio != "none" and not any(s.get("codec_type") == "audio" and s.get("codec_name") for s in streams):
        raise MediaError("Recorder produced no audio track; refusing silent fallback")


def verify_probe(path):
    ffmpeg = command("ffmpeg")
    decoded = subprocess.run([ffmpeg, "-nostdin", "-v", "error", "-i", path, "-t", "8", "-map", "0:v:0", "-an", "-f", "null", "-"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=20)
    if decoded.returncode:
        raise MediaError("Probe video could not be decoded; recording remains disabled")
    audio = subprocess.run([ffmpeg, "-nostdin", "-v", "error", "-i", path, "-t", "8", "-map", "0:a:0", "-ac", "1", "-ar", "8000", "-f", "s16le", "pipe:1"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=20)
    if audio.returncode or not audio.stdout or len(audio.stdout) % 2:
        raise MediaError("Probe system audio could not be decoded; recording remains disabled")
    # Probe only: normal recordings may legitimately contain silence. Require a
    # small audible signal from the deliberate public tone/audio played by user.
    samples = [sample[0] for sample in struct.iter_unpack("<h", audio.stdout)]
    if max(abs(sample) for sample in samples) <= 64 or sum(sample * sample for sample in samples) / len(samples) <= 64:
        raise MediaError("Probe system audio was silent. Play a public test tone through the Mac output and retry; recording remains disabled")


def public_status(value):
    if not value:
        return {"status": "idle"}
    return {key: value[key] for key in ("status", "path", "audio", "error") if key in value}


def refreshed(value):
    if value and value.get("status") in ("starting", "recording", "finalizing") and value.get("supervisor") and not matches(value["supervisor"]):
        live = same_birth(value.get("recorder"))
        value = dict(value, status="orphaned" if live else "failed", error="Recording supervisor is no longer verifiable; no process was signalled")
    return value


def recorder_command(args):
    rect = region(args.region) if args.region else None
    if rect and args.target != "area":
        raise MediaError("--region is only valid for an area recording")
    if args.target == "area" and rect is None:
        if args.platform == "linux":
            rect = selected_region()
    if args.platform == "linux":
        argv = [command("wf-recorder"), "-y"]
        if rect:
            argv.extend(["-g", grim_region(rect)])
        else:
            argv.extend(["-o", linux_monitor(args.monitor)])
        audio = linux_audio(args.audio)
        if audio:
            argv.append("--audio=" + audio)
        return argv
    argv = ["/usr/sbin/screencapture", "-v"]
    if args.target == "area" and rect is None:
        argv.extend(["-i", "-s"])
    else:
        rect = rect or darwin_monitor(args.monitor)
        argv.extend(["-R", ",".join(map(str, rect))])
    if args.audio == "system":
        argv.append("-A")
    elif args.audio == "microphone":
        argv.append("-g")
    return argv


def worker(platform, session, home):
    state = State(home)
    recorder = None
    identity = None
    value = None
    try:
        with state.lock():
            value = state.read()
            if not value or value.get("session") != session or value.get("status") != "starting" or value.get("platform") != platform:
                return 1
            value["supervisor"] = process_identity(os.getpid())
            if not value["supervisor"]:
                raise MediaError("Cannot verify recording supervisor")
            state.write(value)
        recorder = subprocess.Popen([*value["command"], value["path"]], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        # The child belongs to this supervisor and cannot have its PID reused until reaped.
        # Let exec/interpreter wrappers settle before persisting kernel identity.
        time.sleep(0.2)
        if recorder.poll() is not None:
            raise MediaError("Recorder exited unsuccessfully; check Screen/Audio permissions and selected device")
        identity = process_identity(recorder.pid)
        if not identity:
            raise MediaError("Cannot verify recorder identity")
        with state.lock():
            current = state.read()
            if current.get("session") != session:
                raise MediaError("Recording ownership changed")
            current.update(status="recording", recorder=identity)
            state.write(current)
        stopping = False
        while recorder.poll() is None:
            with state.lock():
                current = state.read()
                if current.get("session") != session:
                    raise MediaError("Recording ownership changed")
                if current.get("stop_requested") and not stopping:
                    if not same_birth(identity):
                        raise MediaError("Recorder identity changed; no process was signalled")
                    recorder.send_signal(signal.SIGINT)
                    stopping = True
                    current["status"] = "finalizing"
                    state.write(current)
            time.sleep(0.1)
        if recorder.returncode != 0:
            raise MediaError("Recorder exited unsuccessfully; check Screen/Audio permissions and selected device")
        verify_video(value["path"], value["audio"])
        with state.lock():
            current = state.read()
            if current.get("session") != session:
                raise MediaError("Recording ownership changed")
            current["status"] = "finished"
            current.pop("command", None)
            state.write(current)
    except Exception as error:
        live = recorder is not None and recorder.poll() is None
        if live and same_birth(identity):
            recorder.send_signal(signal.SIGINT)
            try:
                recorder.wait(timeout=10)
                live = False
            except subprocess.TimeoutExpired:
                pass
        if not live and value:
            with contextlib.suppress(OSError, KeyError):
                output = Path(value["path"])
                if not output.is_symlink() and output.is_file() and output.stat().st_size == 0:
                    output.unlink()
        with state.lock():
            current = state.read()
            if current and current.get("session") == session:
                current.update(status="orphaned" if live else "failed", error=str(error) if isinstance(error, MediaError) else "Media supervisor failed")
                current.pop("command", None)
                state.write(current)
        return 1
    finally:
        state.close()
    return 0


def start(args, home, probe=False):
    state = State(home)
    try:
        with state.lock():
            previous = refreshed(state.read())
            if previous and previous.get("status") in ("starting", "recording", "finalizing", "orphaned"):
                raise MediaError("A recording is already active or requires recovery; use record status/stop")
        if args.platform == "darwin" and not probe:
            with state.lock():
                marker = state.read("darwin-verified.json")
            if marker != certificate():
                raise MediaError("Darwin recording is not verified for this OS/executable. Run 'fleet-ui record probe --region x,y,width,height' on a public test region with system audio first")
        argv = recorder_command(args)
        command("ffprobe")
        session = uuid.uuid4().hex
        with state.lock():
            previous = refreshed(state.read())
            if previous and previous.get("status") in ("starting", "recording", "finalizing", "orphaned"):
                raise MediaError("A recording is already active or requires recovery; use record status/stop")
            path = reserve_output(home, "record", args.file)
            state.write({"session": session, "status": "starting", "command": argv, "path": path, "audio": args.audio, "platform": args.platform, "stop_requested": False})
            args.created_session = session
            try:
                process = subprocess.Popen([sys.executable, "-B", str(Path(__file__).resolve()), "--platform", args.platform, "_worker", session], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            except OSError as error:
                state.write({"session": session, "status": "failed", "path": path, "audio": args.audio, "error": "Recording supervisor could not start"})
                Path(path).unlink()
                raise MediaError("Recording supervisor could not start") from error
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            with state.lock():
                value = refreshed(state.read())
            if value.get("status") == "recording":
                # Catch immediate backend refusal before reporting success.
                time.sleep(0.3)
                with state.lock():
                    value = refreshed(state.read())
                if value.get("status") == "recording":
                    return public_status(value)
            if value.get("status") in ("failed", "orphaned", "finished") or process.poll() is not None:
                raise MediaError(value.get("error", "Recorder stopped before startup completed"))
            time.sleep(0.05)
        raise MediaError("Recorder startup is still pending; inspect record status before retrying")
    finally:
        state.close()


def status_or_stop(args, home):
    state = State(home)
    try:
        with state.lock():
            value = refreshed(state.read())
            if getattr(args, "expected_session", None) and value and value.get("session") != args.expected_session:
                return public_status(value)
            if args.operation == "stop" and value and value.get("status") in ("starting", "recording", "finalizing"):
                if not value.get("supervisor") or not matches(value["supervisor"]):
                    raise MediaError("Cannot verify recording supervisor; no process was signalled")
                value["stop_requested"] = True
                state.write(value)
        if args.operation == "stop":
            deadline = time.monotonic() + 15
            while value and value.get("status") in ("starting", "recording", "finalizing") and time.monotonic() < deadline:
                time.sleep(0.1)
                with state.lock():
                    value = refreshed(state.read())
            if value and value.get("status") in ("starting", "recording", "finalizing"):
                return dict(public_status(value), error="Recording stop/finalization is still pending; inspect record status before retrying")
        return public_status(value)
    finally:
        state.close()


def probe(args, home):
    if args.platform != "darwin" or not args.region:
        raise MediaError("The Darwin probe requires an explicit public --region")
    args.target = "area"
    args.audio = "system"
    args.file = "auto"
    before = certificate()
    state = State(home)
    try:
        with state.lock():
            state.remove("darwin-verified.json")
    finally:
        state.close()
    args.created_session = None
    result = None
    try:
        start(args, home, probe=True)
        time.sleep(args.seconds)
    finally:
        if args.created_session:
            args.operation = "stop"
            args.expected_session = args.created_session
            result = status_or_stop(args, home)
    if result is None:
        raise MediaError("Probe did not create its own recording session")
    if result.get("status") != "finished":
        raise MediaError(result.get("error", "Darwin stop/finalization probe failed; recording remains disabled"))
    verify_probe(result["path"])
    if before != certificate():
        raise MediaError("OS/executable changed during probe; recording remains disabled")
    state = State(home)
    try:
        with state.lock():
            state.write(before, "darwin-verified.json")
    finally:
        state.close()
    return dict(result, verified=True)


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--platform", required=True, choices=("darwin", "linux"))
    actions = result.add_subparsers(dest="action", required=True)
    screenshot_parser = actions.add_parser("screenshot")
    screenshot_parser.add_argument("target", choices=("area", "window", "screen"))
    destination = screenshot_parser.add_mutually_exclusive_group()
    destination.add_argument("--clipboard", action="store_true")
    destination.add_argument("--file", default=None)
    screenshot_parser.add_argument("--monitor", default="focused")
    screenshot_parser.add_argument("--region")
    screenshot_parser.add_argument("--window-id", type=int)
    record = actions.add_parser("record")
    operations = record.add_subparsers(dest="operation", required=True)
    record_start = operations.add_parser("start")
    record_start.add_argument("--target", choices=("area", "screen"), default="screen")
    record_start.add_argument("--audio", choices=("system", "none", "microphone"), default="system")
    record_start.add_argument("--monitor", default="focused")
    record_start.add_argument("--region")
    record_start.add_argument("--file", default="auto")
    operations.add_parser("stop")
    operations.add_parser("status")
    record_probe = operations.add_parser("probe", help="Record a deliberate public test region with system audio and verify stop/finalization")
    record_probe.add_argument("--region", required=True)
    record_probe.add_argument("--seconds", type=int, choices=range(1, 6), default=2)
    worker_parser = actions.add_parser("_worker", help=argparse.SUPPRESS)
    worker_parser.add_argument("session")
    return result


def main():
    args = parser().parse_args()
    home = Path.home()
    try:
        if args.action == "_worker":
            return worker(args.platform, args.session, home)
        if args.action == "screenshot":
            result = screenshot(args, home)
        elif args.operation == "start":
            result = start(args, home)
        elif args.operation == "probe":
            result = probe(args, home)
        else:
            result = status_or_stop(args, home)
        print(json.dumps(result))
        if args.action == "record" and args.operation == "stop":
            return 1 if result.get("status") in ("failed", "orphaned", "starting", "recording", "finalizing") else 0
        return 0
    except (MediaError, OSError, ValueError, subprocess.SubprocessError) as error:
        message = str(error) if isinstance(error, MediaError) else "Media action failed; check local ownership, permissions and required commands"
        print(json.dumps({"status": "error", "error": message}))
        return 1


if __name__ == "__main__":
    sys.exit(main())
