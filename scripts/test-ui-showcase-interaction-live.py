#!/usr/bin/env python3
"""G09–G14 display fixtures; only the existing private ISD wrapper is used."""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time

PROJECT = Path(__file__).resolve().parents[1]


def call(*args):
    p = subprocess.run(
        [sys.executable, "-B", str(PROJECT / "scripts/ui_isd.py"), *map(str, args)],
        cwd=PROJECT,
        capture_output=True,
        text=True,
    )
    if p.returncode:
        raise RuntimeError(f"{args}: {p.stdout}\n{p.stderr}")
    return json.loads(p.stdout)


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--isd", type=Path, required=True)
    args = parser.parse_args()
    output = args.output or Path(
        tempfile.mkdtemp(prefix="iv132-display-", dir="/tmp/opencode")
    )
    output.mkdir(parents=True, exist_ok=True)
    captures = []
    sources = {}
    for root in (
        PROJECT / "consumer/ui_showcase",
        PROJECT / "consumer/gestures_demo/model",
        PROJECT / "consumer/virtualized_collections_demo/model",
    ):
        for path in sorted(root.rglob("*.odin")):
            sources[str(path.relative_to(PROJECT))] = hashlib.sha256(
                path.read_bytes()
            ).hexdigest()
    (output / "sources.json").write_text(json.dumps(sources, indent=2))
    print(output, flush=True)
    pages = ("text-input", "scroll-table", "collections", "layers", "hud", "gestures")
    for locale in ("ru", "en"):
        for page in pages:
            native_args = (
                ["--keyboard-layout", "ru" if locale == "ru" else "us"]
                if page == "text-input"
                else []
            )
            record = call(
                "start",
                "--profile",
                "ui-showcase",
                "--isd",
                args.isd.resolve(),
                "--font",
                "resources/font.ttf",
                "--section",
                page,
                "--locale",
                locale,
                "--size",
                "1280x960",
                "--test-controls",
                *native_args,
            )
            run = record["run"]
            log_path = Path(record["root"]) / record["id"] / "app.log"
            try:
                call("focus", run)

                def key(name):
                    codes = {"ctrl+a": 38, "ctrl+c": 54, "ctrl+x": 53, "ctrl+v": 55}
                    if page == "text-input" and name in codes:
                        call("key", run, "down", "Control_L")
                        try:
                            call("keycode", run, "tap", codes[name])
                        finally:
                            call("key", run, "up", "Control_L")
                    else:
                        call("key", run, "tap", name)
                    time.sleep(0.15)

                def mouse(action, *values):
                    call("mouse", run, action, *values)
                    time.sleep(0.15)

                def capture(fixture):
                    filename = f"{locale}-{page}-{fixture}.png"
                    call("screenshot", run, "--output", output / filename)
                    log = log_path.read_text()
                    observed = {}
                    for prefix in (
                        "state ",
                        "names ",
                        "interaction ",
                        "editor ",
                        "hold ",
                        "gesture ",
                    ):
                        lines = [
                            line for line in log.splitlines() if line.startswith(prefix)
                        ]
                        if lines:
                            observed[prefix.strip()] = lines[-1]
                    captures.append(
                        dict(
                            file=filename,
                            fixture=fixture,
                            section=page,
                            locale=locale,
                            drawable=[1280, 960],
                            scale=1,
                            mode="Normal",
                            run=run,
                            timestamp_ns=time.time_ns(),
                            observation=observed,
                            sha256=hashlib.sha256(
                                (output / filename).read_bytes()
                            ).hexdigest(),
                            inspected=False,
                        )
                    )
                    (output / "captures.json").write_text(
                        json.dumps(captures, ensure_ascii=False, indent=2)
                    )

                time.sleep(0.25)
                capture("baseline")
                if page == "text-input":
                    # Ctrl+A physical A position must not be remapped by keysym
                    # lookup under ru. Ordinary text is also a physical key.
                    call("key", run, "down", "Control_L")
                    try:
                        call("keycode", run, "tap", 38)
                    finally:
                        call("key", run, "up", "Control_L")
                    call("keycode", run, "tap", 38)
                    time.sleep(0.15)
                    key("Return")
                    # Odin %q emits escaped non-ASCII code points.
                    text = '"\\u0444"' if locale == "ru" else '"a"'
                    assert f"applied={text}" in log_path.read_text(), (
                        log_path.read_text()
                    )
                    key("ctrl+a")
                    key("ctrl+c")
                    key("ctrl+x")
                    key("ctrl+v")
                    capture("committed-clipboard")
                    key("ctrl+a")
                    capture("selection")
                    key("BackSpace")
                    key("Return")
                    capture("empty-submit-refused")
                    key("Escape")
                elif page == "scroll-table":
                    key("Return")
                    key("Tab")
                    key("Tab")
                    key("Down")
                    key("Return")
                    mouse("move", 100, 260)
                    mouse("click", 5)
                    capture("dataset-selection-wheel")
                elif page == "collections":
                    mouse("move", 100, 150)
                    mouse("click", 1)
                    mouse("move", 1000, 185)
                    mouse("click", 1)
                    capture("grid-end-reveal")
                elif page == "layers":
                    key("Return")
                    capture("modal-a")
                    # The open-B control follows count, eight rows and hold.
                    for _ in range(10):
                        key("Tab")
                    key("Return")
                    capture("modal-b")
                    key("Escape")
                    key("Escape")
                    capture("focus-return")
                    key("Return")
                    mouse("move", 600, 368)
                    mouse("click", 1)
                    capture("popup-shield")
                    key("Escape")
                    key("Escape")
                elif page == "hud":
                    call("key", run, "down", "space")
                    try:
                        time.sleep(0.25)
                        capture("hold-mid")
                        time.sleep(1.05)
                        capture("hold-complete")
                    finally:
                        call("key", run, "up", "space")
                    assert "restore_count=1" in log_path.read_text()
                elif page == "gestures":
                    mouse("move", 30, 290)
                    mouse("down", 1)
                    try:
                        mouse("move", 36, 290)
                        capture("active-preview")
                        mouse("move", 700, 218)
                    finally:
                        mouse("up", 1)
                    capture("drop-outcome")
                key("F12")
                # This bounded wait checks graceful app exit before mandatory stop.
                for _ in range(40):
                    status = call("status", run)
                    if status["app_exit"] is not None:
                        assert status["app_exit"] == 0, status
                        break
                    time.sleep(0.1)
                else:
                    raise AssertionError("graceful exit timeout")
                log = log_path.read_text()
                assert "destroy live=0 bad-frees=0 native-live=0" in log, log
                (output / f"{locale}-{page}.log").write_text(log)
            finally:
                call("stop", run)
    print(f"Display fixtures saved; inspect every PNG: {output}")


if __name__ == "__main__":
    main()
