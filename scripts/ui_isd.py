#!/usr/bin/env python3
"""UI-only build/ISD profile. No production runtime dependency or desktop fallback."""

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time

from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
DISPLAY_ALLOCATION = "linux-abstract-v1"
RUNTIME_DIRS = ("work", "home", "temp", "config", "cache", "data", "state")
SHOWCASE_SECTIONS = (
    "catalogue",
    "layout",
    "controls",
    "profiles",
    "styling",
    "atlas",
    "text",
    "rich-text",
    "text-input",
    "scroll-table",
    "collections",
    "layers",
    "hud",
    "gestures",
    "composition",
    "custom",
    "transitions",
    "accessibility",
    "world",
    "diagnostics-performance",
)
LAB_SECTIONS = ("lab-menu", "lab-settings", "lab-hud", "lab-inventory")
PROFILES = ("standalone-menu", "ui-showcase", "ui-showcase-tools")

# Complete, inspected source snapshots, not a marker/version assertion. No
# external source is bundled or updated. Unknown versions require separate review.
ISD_COMMON = {
    "isd": "46b55654b951f6c494280c94ada987b5ab481e96e403793e2c59035384d38a15",
    "isdlib/__init__.py": "a8b8c3c9c71f3b647750a012f8d1905dd6492c6710d16aa1ac01e14b72320617",
    "isdlib/core.py": "a22003661c09067105ab49925d09093869b7ec4c437d4285721e34a08ebcb56d",
}
ISD_CODE_PINS = (
    (
        "d67f4e5cd81f6253a83a0be0810c66e843748fe9",
        False,
        {
            **ISD_COMMON,
            "isdlib/cli.py": "dc7dfc1cdebbfc362de6f6ea1e2f492f711bc071165e994746901fc19b71d8a6",
            "isdlib/display.py": "404586d67b377167132f392aca78d188a4e1234af1ca626d81af6d2b5a7cbb9e",
            "isdlib/supervisor.py": "12c218fc623fddac51d4ae5aa86ac4814f257b8d54e2742ccf946a4ba39987dc",
        },
    ),
    (
        "f8204c61615406ce5628b15692628e146476a008",
        True,
        {
            **ISD_COMMON,
            "isdlib/cli.py": "36f59ff1501da8be28cebbaeae915361d999124557e6b431ff56be1229b783bb",
            "isdlib/display.py": "976a1f488350d719039a0ee7def1c26c8c413a196f9f79fbad016aab423c1669",
            "isdlib/supervisor.py": "651d43635a50687b34dd092190c6650cb301f990db584527d3aeb750d975e96d",
        },
    ),
)


def verify_isd(binary, native_input=False):
    root = Path(binary).resolve(strict=True).parent
    try:
        if (root / "isdlib").is_symlink():
            raise RuntimeError("ISD source directory is a symlink")
        paths = [root / "isd", *(root / "isdlib").rglob("*.py")]
        if any(p.is_symlink() for p in paths):
            raise RuntimeError("ISD source contains symlinks")
        actual = {
            str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in paths
        }
    except OSError as error:
        raise RuntimeError("Cannot verify whole ISD source") from error
    for revision, native, expected in ISD_CODE_PINS:
        if actual == expected:
            if native_input and not native:
                raise RuntimeError(
                    "Selected verified ISD lacks native layout/keycode; no fallback"
                )
            return {"revision": revision, "native_input": native, "files": actual}
    raise RuntimeError(
        "ISD whole source is not a verified allocation snapshot; no launch"
    )


def find_isd(explicit=None):
    selected = explicit or os.environ.get("ISD_BIN")
    if not selected:
        raise RuntimeError(
            "Explicit --isd or ISD_BIN is required; no discovery/fallback"
        )
    binary = Path(selected).expanduser().resolve(strict=True)
    if not binary.is_file() or not os.access(binary, os.X_OK):
        raise RuntimeError(f"ISD executable unavailable: {binary}")
    verify_isd(binary)
    return binary


def require_allocation(record, response):
    if response.get("display_allocation") != DISPLAY_ALLOCATION:
        raise RuntimeError(
            "Unsafe/unsupported ISD display_allocation; linux-abstract-v1 required"
        )


def call(record, *args):
    if args[0] in (
        "launch",
        "layout",
        "windows",
        "focus",
        "screenshot",
        "key",
        "keycode",
        "mouse",
    ):
        current = verify_isd(
            record["isd"], native_input=args[0] in ("layout", "keycode")
        )
        if record.get("isd_source") != current:
            raise RuntimeError(
                "Selected ISD source changed since create; status/stop only"
            )
        live_status(record)
    result = subprocess.run(
        [record["isd"], "--root", record["root"], *map(str, args)],
        text=True,
        capture_output=True,
    )
    try:
        body = json.loads(result.stdout)
    except ValueError as error:
        raise RuntimeError(f"Invalid ISD JSON (exit {result.returncode})") from error
    if (
        not isinstance(body, dict)
        or type(body.get("protocol")) is not int
        or body["protocol"] != 1
        or body.get("ok") is not True
        or result.returncode
    ):
        raise RuntimeError(f"ISD failed (exit {result.returncode}): {body}")
    if "id" in record and body.get("id") != record["id"]:
        raise RuntimeError("ISD returned a different environment ID")
    return body


def live_status(record):
    status = call(record, "status", record["id"])
    require_allocation(record, status)
    if not status["supervisor_alive"] or not status["xvfb_alive"]:
        raise RuntimeError(f"Isolated display lost: {status}")
    return status


def save_record(run, record):
    temporary = run / "run.json.new"
    temporary.write_text(json.dumps(record, indent=2) + "\n")
    temporary.replace(run / "run.json")


def load_record(run):
    run = Path(run).resolve(strict=True)
    record = json.loads((run / "run.json").read_text())
    if (
        not isinstance(record, dict)
        or record.get("version") != 1
        or record.get("run") != str(run)
        or record.get("root") != str(run / "isd")
        or not Path(record.get("isd", "")).is_absolute()
        or re.fullmatch(r"[0-9a-f]{32}", record.get("id", "")) is None
    ):
        raise RuntimeError(
            "Invalid/incomplete run.json; preserve artifacts and recover through status/stop"
        )
    return record


def settings(run):
    result = {
        "SDL_VIDEODRIVER": "x11",
        "SDL_VIDEO_DRIVER": "x11",
        "SDL_AUDIODRIVER": "dummy",
        "SDL_AUDIO_DRIVER": "dummy",
        "SDL_RENDER_DRIVER": "software",
        "LIBGL_ALWAYS_SOFTWARE": "1",
        "GALLIUM_DRIVER": "llvmpipe",
        "XMODIFIERS": "",
    }
    for key, folder in (
        ("HOME", "home"),
        ("TMPDIR", "temp"),
        ("XDG_CONFIG_HOME", "config"),
        ("XDG_CACHE_HOME", "cache"),
        ("XDG_DATA_HOME", "data"),
        ("XDG_STATE_HOME", "state"),
    ):
        result[key] = str(run / folder)
    # Only explicit child-local native library overrides; never shell settings.
    if "LD_LIBRARY_PATH" in os.environ:
        result["LD_LIBRARY_PATH"] = os.environ["LD_LIBRARY_PATH"]
    return result


def stop(record):
    stopped = call(record, "stop", record["id"])
    if stopped.get("warning"):
        print(f"ISD warning: {stopped['warning']}", file=sys.stderr)
    status = call(record, "status", record["id"])
    if (
        stopped["phase"] != "stopped"
        or status["phase"] != "stopped"
        or any(status[key] for key in ("app_alive", "xvfb_alive", "supervisor_alive"))
    ):
        raise RuntimeError(f"Cleanup incomplete; retain run and retry stop: {status}")
    return {**stopped, "status": status}


def rendered(image, record):
    image.load()
    if image.size != tuple(record["size"]):
        return False
    counts = {
        color: count
        for count, color in image.convert("RGB").getcolors(image.width * image.height)
        or []
    }
    background = counts.get((16, 22, 31), 0)
    if (
        record["profile"] in ("ui-showcase", "ui-showcase-tools")
        and record.get("section") == "lab-settings"
    ):
        background += counts.get((32, 45, 65), 0)
    return (
        background > 1000
        and counts.get((35, 66, 96), 0) > 100
        and counts.get((240, 240, 240), 0) > 20
    )


def wait_ready(record, run, timeout):
    deadline = time.monotonic() + timeout
    title = (
        "Standalone Menu" if record["profile"] == "standalone-menu" else "UI Showcase"
    )
    while time.monotonic() < deadline:
        status = live_status(record)
        if not status["app_alive"]:
            raise RuntimeError(
                f"UI exited before readiness: {status['app_exit']}; see app.log"
            )
        windows = call(record, "windows", record["id"])["windows"]
        matches = [w["id"] for w in windows if w["name"] == title]
        if len(matches) > 1:
            raise RuntimeError("Ambiguous UI window; refusing to guess")
        if matches:
            output = run / f"readiness-{time.time_ns()}.png"
            call(
                record,
                "screenshot",
                record["id"],
                "--window",
                matches[0],
                "--output",
                output,
            )
            with Image.open(output) as image:
                ready = rendered(image, record)
            if ready and live_status(record)["app_alive"]:
                return matches[0]
        time.sleep(0.1)
    raise RuntimeError(
        "No rendered UI window before timeout; inspect retained PNG/logs"
    )


def wait_exit(record, timeout):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        status = live_status(record)
        if status["app_exit"] is not None:
            if status["app_exit"] != 0:
                raise RuntimeError(
                    f"Window check failed: exit {status['app_exit']}; see app.log"
                )
            return status
        time.sleep(0.1)
    raise RuntimeError("Window check timeout; inspect app.log")


def start(
    isd,
    project=PROJECT,
    locale="en",
    timeout=30,
    check=False,
    profile="standalone-menu",
    size="800x600",
    scale=1,
    pixel_perfect=False,
    ui_debug=False,
    ui_profile=None,
    test_time=False,
    consumer_root=None,
    kit_root=None,
    font=None,
    fallback_font=None,
    test_controls=False,
    section=None,
    keyboard_layout=None,
    instrument=False,
    assets=None,
    alternate_assets=None,
):
    tools = profile == "ui-showcase-tools"
    showcase = profile in ("ui-showcase", "ui-showcase-tools")
    qualification = (
        instrument
        and profile in ("standalone-menu", "ui-showcase")
        and test_controls
        and consumer_root is not None
    )
    if (
        profile not in PROFILES
        or locale not in ("ru", "en")
        or not math.isfinite(timeout)
        or timeout <= 0
    ):
        raise RuntimeError("invalid UI profile/locale/timeout")
    if (
        size
        not in (
            ("800x600", "960x720", "1280x960", "320x240")
            if showcase
            else ("800x600", "480x320")
        )
        or scale not in (1, 1.5, 2)
        or (pixel_perfect and (not showcase or scale == 1.5))
    ):
        raise RuntimeError("unsupported size/scale/pixel-perfect")
    if (
        section is not None
        and (not showcase or section not in (*SHOWCASE_SECTIONS, *LAB_SECTIONS))
    ) or (
        not showcase
        and any(x is not None for x in (fallback_font, assets, alternate_assets))
    ):
        raise RuntimeError("unsupported UI section/resources")
    if (
        (
            tools
            and (
                ui_debug != (ui_profile == "showcase-v19")
                or (test_time and not ui_debug)
            )
        )
        or (not tools and (ui_debug or ui_profile is not None or test_time))
        or (instrument and not qualification)
    ):
        raise RuntimeError("showcase tools/instrumentation require explicit gates")
    if keyboard_layout is not None and (
        keyboard_layout not in ("ru", "us")
        or not showcase
        or section not in ("text-input", "gestures", "diagnostics-performance")
    ):
        raise RuntimeError("keyboard layout belongs to native editor sections")
    if font is None:
        raise RuntimeError("explicit --font required")
    font = Path(font).resolve(strict=True)
    consumer_root = Path(
        consumer_root or project / "consumer" / profile.replace("-", "_")
    ).resolve(strict=True)
    kit_root = Path(kit_root or project / "kit").resolve(strict=True)
    if not font.is_file() or not consumer_root.is_dir() or not kit_root.is_dir():
        raise RuntimeError("invalid font/consumer/kit root")
    resources = {}
    for key, path in (
        ("fallback_font", fallback_font),
        ("assets", assets),
        ("alternate_assets", alternate_assets),
    ):
        resources[key] = (
            str(Path(path).resolve(strict=True)) if path is not None else None
        )
    # Direct API callers pass through exactly the same full source preflight.
    isd = find_isd(isd)
    manifest = verify_isd(isd, native_input=keyboard_layout is not None)
    run = Path(tempfile.mkdtemp(prefix="oui-isd-", dir="/tmp/opencode")).resolve()
    print(f"UI ISD artifacts: {run}", file=sys.stderr, flush=True)
    for folder in RUNTIME_DIRS:
        (run / folder).mkdir(mode=0o700)
    if check and showcase:
        test_controls = True
    record = {
        "version": 1,
        "run": str(run),
        "project": str(project),
        "isd": str(isd),
        "isd_source": manifest,
        "root": str(run / "isd"),
        "locale": locale,
        "mode": "window-check" if check else "ui",
        "ready": False,
        "profile": profile,
        "consumer_root": str(consumer_root),
        "kit_root": str(kit_root),
        "font": str(font),
        "size": list(map(int, size.split("x"))),
        "scale": scale,
        "pixel_perfect": pixel_perfect,
        "test_controls": test_controls,
        "section": section or "catalogue",
        "instrument": bool(qualification),
        **resources,
    }
    save_record(run, record)
    binary = build(
        project,
        run,
        profile=profile,
        test_build=test_controls or (tools and ui_debug),
        consumer_root=consumer_root,
        kit_root=kit_root,
        qualification=qualification,
    )
    record["binary_sha256"] = hashlib.sha256(binary.read_bytes()).hexdigest()
    record["build"] = (
        json.loads((run / "build.json").read_text())
        if (run / "build.json").is_file()
        else {"prebuilt": True, "source_identity": "unavailable"}
    )
    record["resources_sha256"] = {
        str(p): hashlib.sha256(Path(p).read_bytes()).hexdigest()
        for p in [str(font), *[p for p in resources.values() if p is not None]]
    }
    record["child_environment"] = settings(run)
    for key in ("assets", "alternate_assets"):
        if resources[key] is None:
            continue
        manifest_path = Path(resources[key])
        try:
            for page in json.loads(manifest_path.read_text()).get("pages", []):
                path = (manifest_path.parent / page["file"]).resolve(strict=True)
                if path.is_relative_to(manifest_path.parent) and path.is_file():
                    record["resources_sha256"][str(path)] = hashlib.sha256(
                        path.read_bytes()
                    ).hexdigest()
        except (OSError, ValueError, KeyError, TypeError):
            pass  # Invalid resources still reach the real app's failure oracle.
    # Recheck all selected executable/module bytes immediately before create.
    if verify_isd(isd, native_input=keyboard_layout is not None) != manifest:
        raise RuntimeError("ISD source changed before create")
    created = call(record, "create", "--size", size)
    ident = created.get("id")
    if not isinstance(ident, str) or re.fullmatch(r"[0-9a-f]{32}", ident) is None:
        raise RuntimeError(f"ISD create returned invalid ID; retain {run} for recovery")
    record["id"] = ident
    try:
        save_record(run, record)
        (run / "create.json").write_text(json.dumps(created, indent=2) + "\n")
        require_allocation(record, created)
        record["display_allocation"] = created["display_allocation"]
        save_record(run, record)
        if keyboard_layout is not None:
            call(record, "layout", ident, keyboard_layout)
            record["keyboard_layout"] = keyboard_layout
        env = [
            part
            for key, value in record["child_environment"].items()
            for part in ("--env", f"{key}={value}")
        ]
        args = [
            "--font",
            str(font),
            "--size",
            size,
            "--scale",
            f"{scale:g}",
            "--locale",
            locale,
        ]
        if test_controls:
            args += ["--test-controls"]
        if qualification:
            args += ["--instrument"]
        if showcase:
            args += ["--section", section or "catalogue"]
            for flag, key in (
                ("--fallback-font", "fallback_font"),
                ("--assets", "assets"),
                ("--alternate-assets", "alternate_assets"),
            ):
                if resources[key] is not None:
                    args += [flag, resources[key]]
            if pixel_perfect:
                args += ["--pixel-perfect"]
        if tools and ui_debug:
            args += ["--ui-debug", "--ui-profile", ui_profile]
        if test_time:
            args += ["--test-time"]
        if check and not showcase:
            args += ["--window-check"]
        call(record, "launch", ident, "--cwd", run / "work", *env, "--", binary, *args)
        if check:
            if showcase:
                record["window"] = wait_ready(record, run, timeout)
                call(record, "focus", ident, "--window", record["window"])
                call(record, "key", ident, "tap", "F12")
            record["app_exit"] = wait_exit(record, timeout)["app_exit"]
            record["check_passed"] = True
            record["stop"] = stop(record)
        else:
            record["window"] = wait_ready(record, run, timeout)
            record["ready"] = True
            if tools and ui_debug:
                log = (run / "isd" / ident / "app.log").read_text()
                endpoints = [
                    json.loads(line)
                    for line in log.splitlines()
                    if line.startswith('{"profile":"showcase-v19",')
                ]
                if (
                    len(endpoints) != 1
                    or set(endpoints[0]) != {"profile", "protocol", "socket"}
                    or endpoints[0]["protocol"] != 19
                    or not isinstance(endpoints[0]["socket"], str)
                    or not Path(endpoints[0]["socket"]).is_absolute()
                ):
                    raise RuntimeError(
                        "showcase-v19 endpoint missing/invalid in this run's log"
                    )
                record["ui_socket"], record["ui_protocol"] = endpoints[0]["socket"], 19
                record["ui_run"] = str(Path(record["ui_socket"]).parent)
        save_record(run, record)
        return record
    except BaseException as failure:
        record["error"], record["ready"] = str(failure), False
        try:
            record["stop"] = stop(record)
        except BaseException as error:
            record["cleanup_error"] = str(error)
            print(f"Cleanup failed: {error}; retry stop using {run}", file=sys.stderr)
        save_record(run, record)
        raise


def source_identity(kit):
    root = Path(kit).resolve(strict=True).parent
    if not (root / ".git").exists():
        try:
            inventory = (root / "inventory.json").read_bytes()
            files = json.loads(inventory)["files"]
            if not files:
                return "unavailable", True
            for name, item in files.items():
                path = root / name
                if (
                    path.is_symlink()
                    or not path.resolve().is_relative_to(root)
                    or hashlib.sha256(path.read_bytes()).hexdigest() != item["sha256"]
                ):
                    return "unavailable", True
            return "inventory-" + hashlib.sha256(inventory).hexdigest(), False
        except (OSError, ValueError, KeyError, TypeError):
            return "unavailable", True
    env = {**os.environ, "GIT_OPTIONAL_LOCKS": "0"}
    top = subprocess.check_output(
        ["git", "rev-parse", "--show-toplevel"], cwd=root, text=True, env=env
    ).strip()
    if Path(top).resolve() != root:
        return "unavailable", True
    revision = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=root, text=True, env=env
    ).strip()
    dirty = bool(
        subprocess.check_output(
            ["git", "status", "--porcelain", "--untracked-files=all"],
            cwd=root,
            text=True,
            env=env,
        )
    )
    return revision, dirty


def build(
    project,
    run,
    profile="standalone-menu",
    test_build=False,
    consumer_root=None,
    kit_root=None,
    qualification=False,
):
    if profile not in PROFILES:
        raise RuntimeError("unsupported UI profile")
    consumer = Path(
        consumer_root or project / "consumer" / profile.replace("-", "_")
    ).resolve(strict=True)
    kit = Path(kit_root or project / "kit").resolve(strict=True)
    binary = run / "ui"
    define = (
        "STANDALONE_MENU_TEST" if profile == "standalone-menu" else "UI_SHOWCASE_TEST"
    )
    flags = [f"-define:{define}=true"] if test_build else []
    revision, dirty = source_identity(kit)
    if qualification:
        if not test_build:
            raise RuntimeError("qualification probes require a test build")
        flags += ["-define:UI_QUALIFICATION=true"]
    if profile == "ui-showcase-tools":
        flags += ["-define:UI_SHOWCASE_TOOLS=true"]
        if test_build:
            flags += ["-define:UI_DEMO_TEST=true"]
        flags += [
            f"-define:UI_BUILD_REVISION={revision}",
            f"-define:UI_BUILD_DIRTY={str(dirty).lower()}",
        ]
    if profile != "standalone-menu":
        linked = subprocess.check_output(
            ["pkg-config", "--libs", "libpng", "zlib"], text=True
        ).strip()
        flags += [f"-extra-linker-flags:{linked}"]
    odin = shutil.which("odin")
    if odin is None:
        raise RuntimeError("Odin is required on PATH")
    with (run / "build.log").open("w") as log:
        result = subprocess.run(
            [
                odin,
                "build",
                str(consumer),
                f"-collection:ui={kit}",
                f"-out:{binary}",
                *flags,
            ],
            cwd=consumer,
            stdout=log,
            stderr=subprocess.STDOUT,
        )
    if result.returncode or not binary.is_file() or not os.access(binary, os.X_OK):
        raise RuntimeError(
            f"Fresh UI build failed; no app launched. See {run / 'build.log'}"
        )
    source_hashes = {
        str(path): hashlib.sha256(path.read_bytes()).hexdigest()
        for directory in (kit, consumer)
        for path in sorted(directory.rglob("*"))
        if path.is_file() and not path.is_symlink() and "__pycache__" not in path.parts
    }
    (run / "build.json").write_text(
        json.dumps(
            {
                "revision": revision,
                "dirty": dirty,
                "kit": str(kit),
                "consumer": str(consumer),
                "sources_sha256": source_hashes,
                "flags": flags,
                "binary_sha256": hashlib.sha256(binary.read_bytes()).hexdigest(),
            },
            indent=2,
        )
        + "\n"
    )
    return binary


def positive_timeout(value):
    value = float(value)
    if not math.isfinite(value) or value <= 0:
        raise argparse.ArgumentTypeError("timeout must be finite and positive")
    return value


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    commands = result.add_subparsers(dest="command", required=True)
    for command in ("start", "check"):
        item = commands.add_parser(command)
        item.add_argument("--isd", type=Path)
        item.add_argument("--profile", choices=PROFILES, default="standalone-menu")
        item.add_argument("--locale", choices=("ru", "en"), default="en")
        item.add_argument("--timeout", type=positive_timeout, default=30)
        item.add_argument("--size", default="800x600")
        item.add_argument("--scale", type=float, default=1)
        for flag in (
            "consumer-root",
            "kit-root",
            "font",
            "fallback-font",
            "assets",
            "alternate-assets",
        ):
            item.add_argument("--" + flag, type=Path)
        item.add_argument("--section")
        item.add_argument("--ui-profile", choices=("showcase-v19",))
        item.add_argument("--keyboard-layout", choices=("ru", "us"))
        for flag in (
            "pixel-perfect",
            "ui-debug",
            "test-controls",
            "test-time",
            "instrument",
        ):
            item.add_argument("--" + flag, action="store_true")
    for command in (
        "stop",
        "status",
        "windows",
        "focus",
        "screenshot",
        "key",
        "keycode",
        "mouse",
    ):
        item = commands.add_parser(command)
        item.add_argument("run", type=Path)
        if command in ("key", "keycode", "mouse"):
            item.add_argument("args", nargs=argparse.REMAINDER)
        if command in ("focus", "screenshot"):
            item.add_argument("--window")
        if command == "screenshot":
            item.add_argument("--output", type=Path, required=True)
    return result


def main(argv=None):
    args = parser().parse_args(argv)
    try:
        if args.command in ("start", "check"):
            options = vars(args).copy()
            command = options.pop("command")
            isd = options.pop("isd")
            result = start(find_isd(isd), check=command == "check", **options)
        else:
            record = load_record(args.run)
            if args.command == "stop":
                result = stop(record)
            elif args.command in ("status", "windows"):
                result = call(record, args.command, record["id"])
            elif args.command in ("key", "keycode", "mouse"):
                result = call(record, args.command, record["id"], *args.args)
            else:
                window = args.window or record.get("window")
                if not window:
                    raise RuntimeError(
                        "No saved window; discover windows and pass --window"
                    )
                extra = (
                    ["--output", args.output.resolve()]
                    if args.command == "screenshot"
                    else []
                )
                result = call(
                    record, args.command, record["id"], "--window", window, *extra
                )
        print(json.dumps({"ok": True, **result}))
        return 0
    except (OSError, ValueError, RuntimeError, KeyError) as error:
        print(json.dumps({"ok": False, "error": str(error)}))
        return 1
    except KeyboardInterrupt:
        print(
            json.dumps(
                {"ok": False, "error": "Interrupted; retain run and check stop/status"}
            )
        )
        return 130


def interrupted(_signum, _frame):
    raise KeyboardInterrupt


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, interrupted)
    sys.exit(main())
