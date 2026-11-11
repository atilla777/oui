#!/usr/bin/env python3
"""Addressed ISD + showcase-v19 scenario; saved pixels still require human/agent inspection."""

import argparse
from contextlib import contextmanager
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import socket
import time
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "showcase_isd", PROJECT / "scripts/ui_isd.py"
)
ISD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ISD)


class Proof:
    def __init__(self, output, isd):
        self.output, self.isd, self.index = output, isd, 0
        self.runs, self.images = [], []

    def wrapper(self, *arguments):
        self.index += 1
        result = subprocess.run(
            [
                sys.executable,
                "-B",
                str(PROJECT / "scripts/ui_isd.py"),
                *map(str, arguments),
            ],
            capture_output=True,
            text=True,
            timeout=120,
        )
        (self.output / f"wrapper-{self.index:04d}.log").write_text(
            result.stdout + "\nSTDERR\n" + result.stderr
        )
        if result.returncode:
            raise RuntimeError(result.stdout + result.stderr)
        return json.loads(result.stdout)

    def cli(self, record, *arguments, refused=None):
        self.index += 1
        result = subprocess.run(
            [
                sys.executable,
                "-B",
                str(PROJECT / "scripts/ui-showcase-cli.py"),
                "--socket",
                record["ui_socket"],
                "--profile",
                "showcase-v19",
                *map(str, arguments),
            ],
            capture_output=True,
            text=True,
            timeout=5,
        )
        (self.output / f"cli-{self.index:04d}.json").write_text(result.stdout)
        (self.output / f"cli-{self.index:04d}.stderr").write_text(result.stderr)
        if result.returncode != (1 if refused else 0):
            raise RuntimeError(
                f"CLI {arguments}: exit={result.returncode}\n{result.stdout}\n{result.stderr}"
            )
        response = json.loads(result.stdout)
        if refused and response["error"]["code"] != refused:
            raise AssertionError(response)
        return response

    @contextmanager
    def run(self, section, locale="ru", size="960x720", scale=1):
        record = None
        try:
            record = self.wrapper(
                "start",
                "--isd",
                self.isd,
                "--profile",
                "ui-showcase-tools",
                "--ui-debug",
                "--ui-profile",
                "showcase-v19",
                "--test-time",
                "--test-controls",
                "--font",
                PROJECT / "resources/font.ttf",
                "--fallback-font",
                PROJECT / "resources/fallback.ttf",
                "--assets",
                PROJECT / "resources/atlas/a/manifest.json",
                "--alternate-assets",
                PROJECT / "resources/atlas/b/manifest.json",
                "--section",
                section,
                "--locale",
                locale,
                "--size",
                size,
                "--scale",
                scale,
            )
            self.runs.append(record)
            self.wrapper("focus", record["run"])
            yield record
            self.wrapper("key", record["run"], "tap", "F12")
            status = ISD.wait_exit(ISD.load_record(Path(record["run"])), 10)
            if status["app_exit"] != 0:
                raise AssertionError(status)
            log = (Path(record["run"]) / "isd" / record["id"] / "app.log").read_text()
            if "destroy live=0 bad-frees=0 native-live=0" not in log:
                raise AssertionError(
                    "native cleanup did not report zero owned live resources: "
                    + log[-1500:]
                )
        finally:
            if record:
                record["final_stop"] = self.wrapper("stop", record["run"])
                self.save()

    def capture(self, record, name):
        reply = self.cli(record, "snapshot")
        packet = Path(reply["result"]["path"])
        manifest = json.loads((packet / "snapshot.json").read_text())
        for field in (
            "frame_id",
            "screen_epoch",
            "model_revision",
            "published_revision",
            "section",
        ):
            if manifest[field] != reply[field]:
                raise AssertionError((field, manifest, reply))
        target = Path(record["run"]) / f"f5-{name}.png"
        self.wrapper("screenshot", record["run"], "--output", target)
        pixels = Image.open(packet / "screenshot.bmp").convert("RGB")
        display = Image.open(target).convert("RGB")
        bmp_view = self.output / f"bmp-view-{self.index:04d}.png"
        pixels.save(bmp_view)
        self.images.append(
            dict(
                png=str(target),
                bmp=str(packet / "screenshot.bmp"),
                bmp_view=str(bmp_view),
                manifest=str(packet / "snapshot.json"),
            )
        )
        assert pixels.size == display.size and pixels.tobytes() == display.tobytes(), (
            "BMP and addressed display pixels differ"
        )
        self.save()

    def save(self):
        (self.output / "results.json").write_text(
            json.dumps(
                dict(runs=self.runs, images=self.images), indent=2, ensure_ascii=False
            )
        )


def values(response):
    return {
        item["id"]: item["value"]
        for item in response["result"]["observation"]["values"]
    }


def controls(proof, locale, size, scale):
    with proof.run("controls", locale, size, scale) as record:
        inventory = proof.cli(record, "list-sections")["result"]["sections"]
        assert (
            len(inventory) == 24
            and inventory[0]["id"] == "catalogue"
            and inventory[-1]["id"] == "lab-inventory"
        )
        assert proof.cli(record, "find", "--id", "controls/checkbox")["result"][
            "ids"
        ] == ["controls/checkbox"]
        inspected = proof.cli(record, "inspect", "controls/checkbox")["result"]["node"]
        geometry = proof.cli(record, "geometry", "controls/checkbox")["result"]
        assert inspected["bounds"] == geometry["bounds"]
        proof.wrapper("key", record["run"], "tap", "Return")
        native = proof.cli(record, "tree")
        assert values(native)["controls/checkbox"] is True
        assert native["result"]["observation"]["last_action"]["source"] == "Keyboard"
        applied = proof.cli(record, "activate", "controls/checkbox")
        assert applied["result"]["application"]["status"] == "applied"
        assert values(applied)["controls/checkbox"] is False
        proof.capture(record, f"controls-{locale}-{scale}")


def table(proof, locale, size, scale):
    with proof.run("scroll-table", locale, size, scale) as record:
        proof.cli(record, "scroll", "table/viewport", "--delta-y", 1200)
        proof.capture(record, f"table-{locale}-{scale}")


def hud(proof, locale, size, scale):
    with proof.run("hud", locale, size, scale) as record:
        proof.cli(record, "activate", "hud/restore", refused="Hold_Required")
        proof.cli(record, "begin-hold", "hud/restore")
        partial = proof.cli(record, "advance-hold", "--duration-ms", 999)
        assert values(partial)["hud/count"] == 0
        proof.capture(record, f"hud-partial-{locale}-{scale}")
        released = proof.cli(record, "release-hold")
        assert values(released)["hud/count"] == 0
        proof.cli(record, "begin-hold", "hud/restore")
        complete = proof.cli(record, "advance-hold", "--duration-ms", 1000)
        assert values(complete)["hud/count"] == 1
        proof.capture(record, f"hud-complete-{locale}-{scale}")
        proof.cli(record, "release-hold")


def settings(proof, locale, scale):
    with proof.run("lab-settings", locale, "1280x960", scale) as record:
        proof.cli(record, "activate", "lab/enabled")
        proof.cli(record, "activate", "name/apply")
        proof.cli(record, "select-section", "controls", refused="Blocked_By_Modal")
        proof.capture(record, f"settings-confirm-{locale}-{scale}")
        proof.cli(record, "cancel")
        pending = proof.cli(record, "select-section", "controls")
        assert pending["result"]["selection"]["status"] == "pending"
        proof.cli(record, "activate", "lab/stay")
        assert values(proof.cli(record, "tree"))["lab/dirty"] is True
        proof.cli(record, "select-section", "controls")
        proof.capture(record, f"settings-discard-{locale}-{scale}")
        proof.cli(record, "activate", "lab/discard")
        assert proof.cli(record, "tree")["section"] == "controls"


def recovery(proof):
    with proof.run("controls", "en", "960x720", 1) as record:
        endpoint = Path(record["ui_socket"])
        assert endpoint.stat().st_mode & 0o777 == 0o600
        assert endpoint.parent.stat().st_mode & 0o777 == 0o700
        proof.wrapper(
            "key", record["run"], "tap", "F4"
        )  # checked copy fault, after model acceptance
        failed = proof.cli(record, "activate", "controls/checkbox", refused="Not_Ready")
        assert failed["result"]["effects_after"] == 1
        assert failed["result"]["dispatch"]["code"] == "Applied"
        assert failed["result"]["dispatch"]["has_event"] is True
        assert failed["result"]["application"]["status"] == "applied"
        historical = proof.cli(record, "tree")
        assert historical["historical"] and not historical["ready"]
        assert historical["model_revision"] > historical["published_revision"]
        assert (
            historical["result"]["observation"]["last_action"]["application_status"]
            == "applied"
        )
        proof.cli(record, "activate", "controls/checkbox", refused="Not_Ready")
        proof.cli(record, "snapshot", refused="Not_Ready")
        proof.wrapper("key", record["run"], "tap", "r")
        restored = proof.cli(record, "tree")
        assert restored["ready"] and values(restored)["controls/checkbox"] is True
        assert restored["result"]["observation"]["effects"] == 1
        # Intentionally discard a real reply. The following loop is read-only
        # observation, not transport retry or request-id deduplication.
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
            connection.connect(str(endpoint))
            connection.sendall(
                b'{"protocol":19,"request_id":"lost-reply-once","op":"activate","id":"controls/checkbox"}\n'
            )
            # Keep the read side alive until one byte proves processing, then
            # discard the complete outcome. No mutation is ever resent.
            connection.settimeout(2)
            assert connection.recv(1)
        for _ in range(20):
            observed = proof.cli(record, "tree")
            action = observed["result"]["observation"]["last_action"]
            if action and action["request_id"] == "lost-reply-once":
                break
            time.sleep(0.02)
        else:
            raise AssertionError("lost-reply action not observed")
        assert observed["result"]["observation"]["effects"] == 2
        assert values(observed)["controls/checkbox"] is False
        proof.wrapper("key", record["run"], "tap", "r")
        final = proof.cli(record, "tree")
        assert (
            final["result"]["observation"]["effects"] == 2
            and values(final)["controls/checkbox"] is False
        )
        proof.capture(record, "recovered-no-replay")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--isd", required=True)
    parser.add_argument(
        "--only",
        choices=["smoke", "matrix", "selectors", "recovery", "all"],
        default="all",
    )
    args = parser.parse_args()
    output = Path(tempfile.mkdtemp(prefix="iv15-live-", dir="/tmp/opencode"))
    proof = Proof(output, args.isd)
    print(output, flush=True)
    try:
        if args.only == "smoke":
            controls(proof, "ru", "960x720", 1)
        elif args.only in ("matrix", "all"):
            for locale in ("ru", "en"):
                for size, scale in (("960x720", 1), ("1280x960", 1.5)):
                    controls(proof, locale, size, scale)
                    table(proof, locale, size, scale)
                    hud(proof, locale, size, scale)
                for scale in (1, 1.5):
                    settings(proof, locale, scale)
        if args.only in ("recovery", "all"):
            recovery(proof)
        if args.only in ("selectors", "all"):
            with proof.run("catalogue", "ru", "1280x960", 1) as record:
                sections = proof.cli(record, "list-sections")["result"]["sections"]
                assert len(sections) == 24
                for section in sections:
                    assert section["resources_available"], section
                    selected = proof.cli(record, "select-section", section["id"])
                    assert selected["section"] == section["id"] and selected["ready"]
                    tree = proof.cli(record, "tree")
                    assert tree["result"]["nodes"]
                    proof.capture(record, "selector-" + section["id"])
    finally:
        proof.save()


if __name__ == "__main__":
    main()
