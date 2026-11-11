#!/usr/bin/env python3
"""Build/run independent own strings/font binding outside the oui source root.

Real SDL/TTF metrics under dummy are not display/readability evidence.
"""

from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
work = Path(tempfile.mkdtemp(prefix="oui-external-", dir="/tmp/opencode"))
(work / "app").mkdir()
shutil.copyfile(ROOT / "tests/external_consumer/main.odin", work / "app/main.odin")
shutil.copyfile(ROOT / "resources/font.ttf", work / "outside-font.ttf")
command = [
    "odin",
    "build",
    "app",
    f"-collection:ui={ROOT / 'kit'}",
    "-vet",
    "-vet-style",
    "-vet-tabs",
    "-vet-semicolon",
    "-show-import-graph",
    f"-out:{work / 'outside'}",
]
with (work / "build.log").open("w") as log:
    subprocess.run(command, cwd=work, check=True, stdout=log, stderr=subprocess.STDOUT)
graph = (work / "build.log").read_text()
assert str(ROOT / "kit/ui_sdl_text") in graph
assert str(work / "app") in graph
assert str(ROOT / "consumer") not in graph
for excluded in (
    "ui_debug",
    "ui_testing",
    "ui_controls",
    "ui_editor",
    "ui_collections",
    "translations",
):
    assert (
        "/kit/" + excluded + "/" not in graph and "/kit/" + excluded + '"' not in graph
    ), excluded
result = subprocess.run(
    [str(work / "outside"), str(work / "outside-font.ttf")],
    cwd=work,
    env={**os.environ, "SDL_VIDEODRIVER": "dummy", "SDL_AUDIODRIVER": "dummy"},
    check=True,
    text=True,
    capture_output=True,
)
(work / "run.log").write_text(result.stdout + result.stderr)
assert (
    result.stdout.strip()
    == "external-consumer count=7 own-captions=2 font=outside-font"
)
(work / "manifest.json").write_text(
    json.dumps(
        {
            "command": command,
            "dummy_only": True,
            "sha256": {
                str(p.relative_to(work)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in (
                    work / "app/main.odin",
                    work / "outside-font.ttf",
                    work / "outside",
                )
            },
        },
        indent=2,
    )
    + "\n"
)
print(work)
