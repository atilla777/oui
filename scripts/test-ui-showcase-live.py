#!/usr/bin/env python3
"""Display evidence via the project ISD wrapper only; no consumer endpoint."""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
WRAPPER = PROJECT / "scripts/ui_isd.py"


def call(*args):
    result = subprocess.run(
        [sys.executable, "-B", str(WRAPPER), *map(str, args)],
        cwd=PROJECT,
        text=True,
        capture_output=True,
    )
    if result.returncode:
        raise RuntimeError(f"wrapper {args}: {result.stdout}\n{result.stderr}")
    return json.loads(result.stdout)


def save_capture(record, output, filename, fixture):
    png = output / filename
    call("screenshot", record["run"], "--output", png)
    log = (Path(record["root"]) / record["id"] / "app.log").read_text()
    observed = {}
    for prefix in ("state ", "gallery ", "lab "):
        lines = [line for line in log.splitlines() if line.startswith(prefix)]
        if lines:
            observed[prefix.strip()] = dict(
                part.split("=", 1) for part in lines[-1].split()[1:]
            )
    with Image.open(png) as image:
        drawable = list(image.size)
    manifest = output / "captures.json"
    entries = json.loads(manifest.read_text()) if manifest.exists() else []
    entries.append(
        {
            "png": str(png),
            "fixture": fixture,
            "wall_time_ns": time.time_ns(),
            "drawable": drawable,
            "observed": observed,
            "run": record["run"],
            "initial_options": record,
            "sources_sha256": hashlib.sha256(
                (output / "sources.sha256").read_bytes()
            ).hexdigest(),
        }
    )
    manifest.write_text(json.dumps(entries, indent=2))


def gallery(args, output, records):
    """Native ordinary controls, not remote setters or a second UI runner."""
    for locale in ("ru", "en"):
        pages = (
            "catalogue",
            "layout",
            "controls",
            "profiles",
            "styling",
            "atlas",
            "text",
            "rich-text",
        )
        if args.full_gallery:
            pages += (
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
        for page in pages:
            record = None
            label = f"gallery-{locale}-{page}"
            try:
                record = call(
                    "start",
                    "--profile",
                    "ui-showcase",
                    "--consumer-root",
                    args.proof / "consumer/ui_showcase",
                    "--kit-root",
                    args.proof / "kit",
                    "--font",
                    args.proof / "resources/font.ttf",
                    "--fallback-font",
                    args.proof / "resources/fallback.ttf",
                    "--assets",
                    args.proof / "resources/atlas/a/manifest.json",
                    "--alternate-assets",
                    args.proof / "resources/atlas/b/manifest.json",
                    "--section",
                    page,
                    "--locale",
                    locale,
                    "--size",
                    "1280x960",
                    "--scale",
                    "1",
                    "--test-controls",
                    *(["--isd", args.isd] if args.isd else []),
                )
                records.append(record)
                (output / "runs.json").write_text(json.dumps(records, indent=2))
                run = record["run"]
                call("focus", run)

                def state(prefix="state "):
                    time.sleep(0.08)
                    log = (Path(record["root"]) / record["id"] / "app.log").read_text()
                    line = [x for x in log.splitlines() if x.startswith(prefix)][-1]
                    return dict(part.split("=", 1) for part in line.split()[1:])

                def focus(target):
                    for _ in range(64):
                        current = state()
                        assert current["ready"] == "true", current
                        if current["focus"] == target:
                            return
                        call("key", run, "tap", "Tab")
                    raise AssertionError(
                        (label, "native Tab cannot reach", target, state())
                    )

                def activate(target):
                    focus(target)
                    call("key", run, "tap", "Return")
                    assert state()["ready"] == "true", (label, state())

                def capture(suffix):
                    save_capture(
                        record, output, f"{label}-{suffix}.png", f"{page}/{suffix}"
                    )

                def item(namespace, value):
                    return f"{len(namespace)}:{namespace}{len(value)}:{value}"

                capture("baseline-1280x960")
                if args.baseline_only:
                    pass
                elif page == "catalogue":
                    for offset in range(2, 20, 2):
                        activate("catalogue/next")
                        capture(f"metadata-{offset}")
                elif page == "layout":
                    activate("layout/more")
                    capture("constraints")
                    activate("layout/safe-area")
                    capture("safe-area")
                elif page == "controls":
                    activate("controls/checkbox")
                    activate("controls/toggle")
                    focus("controls/slider")
                    call("key", run, "tap", "Home")
                    call("key", run, "tap", "Right")
                    assert state()["checkbox"] == state()["toggle"] == "true"
                    assert state()["slider"] == "1"
                    capture("values")
                elif page == "profiles":
                    activate("profiles/help")
                    activate(item("profiles/list", "borealis"))
                    assert state("gallery ")["dialog"] == "Dirty_Departure"
                    capture("dirty-dialog")
                    call("key", run, "tap", "Escape")
                    assert state("gallery ")["profile"] == "aurora"
                    activate("profiles/apply")
                    assert state("gallery ")["applied_help"] == "false"
                    activate(item("profiles/tabs", "appearance"))
                    activate("profiles/mode")
                    capture("select-open")
                    activate(item("profiles/mode", "vivid"))
                    assert state("gallery ")["draft_mode"] == "vivid"
                    capture("draft-mode")
                    activate("profiles/cancel")
                    assert state("gallery ")["draft_mode"] == "normal"
                elif page == "styling":
                    activate("styling/selected")
                    activate("styling/theme")
                    capture("selected-theme")
                    activate("styling/disabled")
                    capture("disabled")
                    activate("styling/fallback")
                    capture("missing-resource")
                elif page == "atlas":
                    activate("atlas/button")
                    assert state("gallery ")["atlas_count"] == "1"
                    activate("atlas/assets")
                    activate("atlas/theme")
                    activate("atlas/selected")
                    capture("B-dark-selected")
                    activate("atlas/reload")
                    assert state("gallery ")["atlas_count"] == "1"
                    activate("atlas/disabled")
                    capture("disabled")
                elif page == "text":
                    for fixture in range(4):
                        assert state("gallery ")["text_case"] == str(fixture)
                        capture(f"limit-{fixture}")
                        activate("text/limit")
                    activate("text/key")
                    capture("short-key")
                elif page == "rich-text":
                    activate("rich/limit")
                    capture("ellipsis")
                elif page == "composition":
                    activate("composition/child")
                    activate("composition/stop")
                    activate("composition/child")
                    capture("routed-stop-and-bubble")
                    activate("composition/presence")
                    capture("child-removed")
                    activate("composition/presence")
                elif page == "custom":
                    activate("custom/style")
                    activate("custom/slot")
                    capture("style-slots")
                    activate("custom/disabled")
                    capture("disabled-circles")
                    activate("custom/disabled")
                    activate("custom/popup")
                    capture("popup-shield")
                    call("key", run, "tap", "Escape")
                    activate("custom/tooltip")
                    capture("noninteractive-tooltip")
                    activate("custom/tooltip")
                elif page == "transitions":
                    activate("transitions/b")
                    capture("mid-motion")
                    time.sleep(1.25)
                    capture("target-b")
                    activate("transitions/presence")
                    capture("exiting")
                    time.sleep(0.5)
                    capture("hidden-no-input")
                    activate("transitions/presence")
                    time.sleep(0.5)
                    activate("transitions/reduced")
                    activate("transitions/a")
                    capture("reduced-motion")
                elif page == "accessibility":
                    activate("accessibility/mode")
                    before = int(state()["effects"])
                    activate("accessibility/action")
                    capture("dialog-initial-cancel")
                    call("key", run, "tap", "Escape")
                    assert int(state()["effects"]) == before
                    activate("accessibility/action")
                    activate(item("accessibility/dialog", "confirm"))
                    assert int(state()["effects"]) == before + 1
                    activate("accessibility/thresholds")
                    activate("accessibility/strict")
                    capture("confirmed-strict-unassessed")
                    activate("accessibility/reduced")
                    activate("accessibility/target")
                    capture("reduced-motion")
                elif page == "world":
                    activate("world/object-left")
                    activate("world/camera-right")
                    activate("world/zoom")
                    activate("world/policy")
                    capture("clamp-camera-zoom")
                    activate("world/policy")
                    capture("direction-fixed-indicator")
                    activate("world/reset")
                elif page == "diagnostics-performance":
                    for kind in (
                        "duplicate",
                        "invalid",
                        "resource",
                        "ownership",
                        "unsupported",
                    ):
                        activate("diagnostics/" + kind)
                        capture("diagnostic-" + kind)
                    activate("performance/instrumentation")
                    capture("instrumentation-off")
                    activate("performance/instrumentation")
                # One meaningful resize per page, using the existing native F10 path.
                sizes = (
                    ("1200x900", "1280x960")
                    if page in ("accessibility", "world", "diagnostics-performance")
                    else ("800x600", "960x720")
                )
                for size in () if args.baseline_only else sizes:
                    call("key", run, "tap", "F10")
                    assert state()["ready"] == "true", (label, size, state())
                    capture(f"resize-{size}")
                # The usual F2 failure barrier/recovery path also exercises new owners.
                if not args.baseline_only and page in (
                    "atlas",
                    "rich-text",
                    "text",
                    "styling",
                    "profiles",
                ):
                    focus("shell/language")
                    before = state()
                    call(
                        "key", run, "tap", "F4"
                    )  # Next rebuild refuses at owning-copy seam.
                    call("key", run, "tap", "Return")
                    failed = state()
                    assert (
                        failed["ready"] == "false"
                        and int(failed["effects"]) == int(before["effects"]) + 1
                    )
                    call("key", run, "tap", "Return")
                    assert state()["effects"] == failed["effects"]
                    call("key", run, "tap", "r")
                    assert (
                        state()["ready"] == "true"
                        and state()["effects"] == failed["effects"]
                    )
                    capture("recovered")
                call("key", run, "tap", "F12")
                for _ in range(40):
                    status = call("status", run)
                    if status["app_exit"] is not None:
                        assert status["app_exit"] == 0, status
                        break
                    time.sleep(0.1)
                else:
                    raise AssertionError("graceful gallery exit timeout")
                log = (Path(record["root"]) / record["id"] / "app.log").read_text()
                assert "destroy live=0 bad-frees=0 native-live=0" in log, log
                assert "unexpected layout diagnostic" not in log, log
                (output / f"{label}.log").write_text(log)
            finally:
                if record is not None:
                    (output / f"{label}-stop.json").write_text(
                        json.dumps(call("stop", record["run"]), indent=2)
                    )


def lab(args, output, records):
    """F4 recipes through the same wrapper, binary, native controls and capture manifest."""
    for locale in ("ru", "en"):
        for page in ("lab-menu", "lab-settings", "lab-hud", "lab-inventory"):
            for scale, pixel in (
                (("1", False),)
                if args.portable_smoke
                else (
                    ("1", False),
                    ("1.5", False),
                    ("2", False),
                    ("1", True),
                    ("2", True),
                )
            ):
                record = None
                label = f"{page}-{locale}-{scale}-{'pixel' if pixel else 'normal'}"
                try:
                    record = call(
                        "start",
                        "--profile",
                        "ui-showcase",
                        "--section",
                        page,
                        "--consumer-root",
                        args.proof / "consumer/ui_showcase",
                        "--kit-root",
                        args.proof / "kit",
                        "--font",
                        args.proof / "resources/font.ttf",
                        "--locale",
                        locale,
                        "--size",
                        "1280x960",
                        "--scale",
                        scale,
                        "--test-controls",
                        *(["--pixel-perfect"] if pixel else []),
                        *(["--isd", args.isd] if args.isd else []),
                    )
                    records.append(record)
                    (output / "runs.json").write_text(json.dumps(records, indent=2))
                    run = record["run"]
                    call("focus", run)

                    def state(prefix="state "):
                        time.sleep(0.08)
                        log = (
                            Path(record["root"]) / record["id"] / "app.log"
                        ).read_text()
                        line = [x for x in log.splitlines() if x.startswith(prefix)][-1]
                        return dict(part.split("=", 1) for part in line.split()[1:])

                    def focus(target):
                        for _ in range(64):
                            now = state()
                            assert now["ready"] == "true", (label, now)
                            if now["focus"] == target:
                                return
                            call("key", run, "tap", "Tab")
                        raise AssertionError(
                            (label, "unreachable focus", target, state())
                        )

                    def activate(target):
                        focus(target)
                        call("key", run, "tap", "Return")
                        assert state()["ready"] == "true", (label, state())

                    def capture(suffix):
                        if args.portable_smoke and suffix not in (
                            "baseline",
                            "applied",
                            "hold-completed",
                            "transferred-reversed",
                        ):
                            return
                        save_capture(
                            record,
                            output,
                            f"{label}-{suffix}.png",
                            f"F4/{page}/{suffix}",
                        )

                    capture("baseline")
                    if scale == "1" and not pixel and not args.baseline_only:
                        call("key", run, "tap", "F10")
                        assert state()["ready"] == "true"
                        capture("resize-960x720")
                        call("key", run, "tap", "F10")
                        assert state()["ready"] == "true"
                        capture("resize-back-1280x960")
                        if page in ("lab-menu", "lab-settings"):
                            if page == "lab-menu":
                                activate("lab/submenu")
                                activate("lab/settings")
                            activate("lab/enabled")
                            activate("name/apply")
                            assert state("lab ")["applied_enabled"] == "false"
                            capture("apply-confirmation")
                            call("key", run, "tap", "Escape")
                            assert state("lab ")["enabled"] == "true"
                            activate("name/apply")
                            activate("lab/confirm")
                            assert state("lab ")["applied_enabled"] == "true"
                            capture("applied")
                            activate("lab/enabled")
                            activate("name/cancel")
                            capture("discard-question")
                            activate("lab/stay")
                            activate("name/cancel")
                            activate("lab/discard")
                            assert state("lab ")["enabled"] == "true"
                            capture("returned-submenu")
                        elif page == "lab-hud":
                            activate("hud/minus")
                            focus("hud/restore")
                            call("key", run, "down", "space")
                            try:
                                # CLI/status/readback already consume wall time.
                                # Observe an actual in-progress state, not a
                                # completed hold mislabeled by a fixed sleep.
                                assert state("lab ")["hold_count"] == "0"
                                capture("hold-active")
                                assert state("lab ")["hold_count"] == "0"
                                time.sleep(1.1)
                            finally:
                                call("key", run, "up", "space")
                            assert (
                                state("lab ")["hp"] == "100"
                                and state("lab ")["hold_count"] == "1"
                            )
                            capture("hold-completed")
                            activate("lab/popup")
                            capture("popup")
                            call("key", run, "tap", "Escape")
                            activate("lab/tooltip")
                            capture("tooltip")
                        else:
                            # Native logical navigation reveals the offscreen sixth row.
                            for _ in range(5):
                                call("key", run, "tap", "Down")
                            call("key", run, "tap", "Return")
                            assert state("lab ")["selected"] == "card-06"
                            capture("offscreen-selected")

                            def drag():
                                call("mouse", run, "move", 660, 348)
                                call("mouse", run, "down", 1)
                                try:
                                    call("mouse", run, "move", 666, 348)
                                    call("mouse", run, "move", 660, 144)
                                finally:
                                    call("mouse", run, "up", 1)
                                assert state("lab ")["pending"] == "true", state("lab ")

                            drag()
                            assert (
                                state("lab ")["left"] == state("lab ")["right"] == "6"
                            )
                            capture("transfer-confirmation")
                            call("key", run, "tap", "Escape")
                            drag()
                            call("key", run, "tap", "F6")
                            time.sleep(0.1)
                            assert state()["ready"] == "false"
                            call("key", run, "tap", "r")
                            assert state("lab ")["pending"] == "true"
                            activate("lab/transfer-confirm")
                            assert (
                                state("lab ")["left"] == "5"
                                and state("lab ")["right"] == "7"
                            )
                            activate("lab/reverse")
                            capture("transferred-reversed")
                    call("key", run, "tap", "F12")
                    for _ in range(30):
                        status = call("status", run)
                        if status["app_exit"] is not None:
                            assert status["app_exit"] == 0, status
                            break
                        time.sleep(0.1)
                    else:
                        raise AssertionError("graceful exit timeout")
                    log = (Path(record["root"]) / record["id"] / "app.log").read_text()
                    (output / f"{label}.log").write_text(log)
                    assert "destroy live=0 bad-frees=0 native-live=0" in log, log
                    assert "unexpected layout diagnostic" not in log, log
                finally:
                    if record is not None:
                        (output / f"{label}-stop.json").write_text(
                            json.dumps(call("stop", record["run"]), indent=2)
                        )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--proof", type=Path, required=True)
    parser.add_argument("--isd", type=Path)
    parser.add_argument("--full-gallery", action="store_true")
    parser.add_argument("--baseline-only", action="store_true")
    parser.add_argument(
        "--portable-smoke",
        action="store_true",
        help="bounded Lab Normal1 ru/en; not full qualification",
    )
    choice = parser.add_mutually_exclusive_group()
    choice.add_argument("--gallery-only", action="store_true")
    choice.add_argument("--f2-only", action="store_true")
    choice.add_argument("--lab-only", action="store_true")
    args = parser.parse_args()
    output = Path(
        tempfile.mkdtemp(prefix="slyx-showcase-display-", dir="/tmp/opencode")
    )
    print(output, flush=True)
    source_evidence = args.proof / "sources.sha256"
    if not source_evidence.is_file():
        source_evidence = args.proof / "inventory.json"
    (output / "sources.sha256").write_bytes(source_evidence.read_bytes())
    (output / "environment.log").write_bytes(
        (
            args.proof
            / ("build/environment.log" if args.portable_smoke else "environment.log")
        ).read_bytes()
    )
    records = []
    if args.lab_only:
        lab(args, output, records)
        print(
            f"Lab display/native checks passed; inspect every PNG separately: {output}"
        )
        return
    for locale in () if args.gallery_only else ("ru", "en"):
        for scale, pixel in (
            ("1", False),
            ("1.5", False),
            ("2", False),
            ("1", True),
            ("2", True),
        ):
            record = None
            label = f"{locale}-{scale}-{'pixel' if pixel else 'normal'}"
            try:
                flags = ["--pixel-perfect"] if pixel else []
                record = call(
                    "start",
                    "--profile",
                    "ui-showcase",
                    "--font",
                    args.proof / "resources/font.ttf",
                    "--consumer-root",
                    args.proof / "consumer/ui_showcase",
                    "--kit-root",
                    args.proof / "kit",
                    "--locale",
                    locale,
                    "--size",
                    "960x720",
                    "--scale",
                    scale,
                    "--test-controls",
                    *flags,
                    *(["--isd", args.isd] if args.isd else []),
                )
                run = record["run"]
                records.append(record)
                (output / "runs.json").write_text(json.dumps(records, indent=2))
                call("focus", run)  # Explicit focus, only this run.
                for page in ("catalogue", "layout", "controls"):
                    for size in ("960x720", "800x600"):
                        time.sleep(0.12)
                        png = output / f"{label}-{page}-{size}.png"
                        save_capture(record, output, png.name, f"F2/{page}/{size}")
                        call(
                            "key", run, "tap", "F10"
                        )  # Native same-window resize there and back.
                    time.sleep(0.12)
                    if page != "controls":
                        call("key", run, "tap", "Return")
                # Controls initial focus is Checkbox; this is native, not a model setter.
                call("key", run, "tap", "Return")
                call("key", run, "tap", "Tab")
                call("key", run, "tap", "Return")
                call("key", run, "tap", "Tab")
                call("key", run, "tap", "Home")
                call("key", run, "tap", "Right")
                time.sleep(0.12)
                save_capture(
                    record, output, f"{label}-values.png", "F2/controlled-values"
                )
                if label == "ru-1-normal":

                    def click(x, y):
                        call("mouse", run, "move", x, y)
                        call("mouse", run, "click", 1)

                    def state():
                        time.sleep(0.12)
                        log = (
                            Path(record["root"]) / record["id"] / "app.log"
                        ).read_text()
                        line = [
                            line
                            for line in log.splitlines()
                            if line.startswith("state ")
                        ][-1]
                        return dict(part.split("=", 1) for part in line.split()[1:])

                    click(160, 69)
                    click(480, 69)
                    assert state()["scale"] == "1.5"
                    click(480, 104)
                    click(800, 138)
                    click(480, 138)
                    before = state()
                    click(480, 69)
                    after = state()
                    assert (
                        before["effects"] == after["effects"]
                        and after["scale"] == "1"
                        and after["pixel"] == "true"
                    ), after
                    save_capture(
                        record, output, "native-parameters.png", "F2/native-parameters"
                    )
                    click(240, 40)
                    call("key", run, "tap", "Return")
                    call("key", run, "tap", "Return")
                    assert (
                        state()["checkbox"] == "true"
                        and state()["toggle"] == "true"
                        and state()["slider"] == "1"
                    )
                    before = state()
                    call("key", run, "tap", "F2")
                    call("key", run, "tap", "Return")
                    failed = state()
                    assert (
                        failed["ready"] == "false"
                        and failed["checkbox"] == "false"
                        and int(failed["effects"]) == int(before["effects"]) + 1
                    )
                    call("key", run, "tap", "Return")
                    call("key", run, "tap", "F10")
                    assert state()["ready"] == "false"
                    call("key", run, "tap", "r")
                    recovered = state()
                    assert (
                        recovered["ready"] == "true"
                        and recovered["effects"] == failed["effects"]
                        and recovered["checkbox"] == "false"
                    )
                    call("key", run, "tap", "F1")
                    click(200, 40)
                    assert (
                        state()["page"] == "Catalogue"
                        and state()["ready"] == "false"
                        and state()["native"] == "0"
                    )
                    call("key", run, "tap", "r")
                    call("key", run, "tap", "Return")
                    call("key", run, "tap", "Return")
                    assert (
                        state()["page"] == "Controls" and state()["checkbox"] == "false"
                    )
                    save_capture(
                        record, output, "native-recovered.png", "F2/native-recovered"
                    )
                call("key", run, "tap", "F12")
                for _ in range(30):
                    status = call("status", run)
                    if status["app_exit"] is not None:
                        assert status["app_exit"] == 0, status
                        break
                    time.sleep(0.1)
                else:
                    raise AssertionError("graceful exit timeout")
                log = (Path(record["root"]) / record["id"] / "app.log").read_text()
                assert "checkbox=true toggle=true slider=1" in log, log
                assert "destroy live=0 bad-frees=0 native-live=0" in log, log
                assert "unexpected layout diagnostic" not in log, log
                if label != "ru-1-normal":
                    assert "ready=false" not in log, log
                (output / f"{label}.log").write_text(log)
            finally:
                if record is not None:
                    stopped = call("stop", record["run"])
                    (output / f"{label}-stop.json").write_text(
                        json.dumps(stopped, indent=2)
                    )
    if not args.f2_only:
        gallery(args, output, records)
    (output / "sources.sha256").write_bytes(
        (args.proof / "sources.sha256").read_bytes()
    )
    (output / "environment.log").write_bytes(
        (args.proof / "environment.log").read_bytes()
    )
    print(
        f"Display/native matrix passed; every PNG still requires visual inspection: {output}"
    )


if __name__ == "__main__":
    main()
