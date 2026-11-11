#!/usr/bin/env python3
"""Exercise real prebuilt debug/release/test binaries through the ISD wrapper."""

import argparse
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "showcase_isd", ROOT / "scripts/ui_isd.py"
)
isd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(isd)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--proof", type=Path, required=True)
    parser.add_argument("--isd", type=Path, required=True)
    args = parser.parse_args()
    proof = args.proof.resolve(strict=True)
    output = Path(tempfile.mkdtemp(prefix="iv15-endpoint-gates-", dir="/tmp/opencode"))
    print(output, flush=True)
    results = []
    for mode, enabled in (
        ("release", False),
        ("debug", False),
        ("debug", True),
        ("test", False),
        ("test", True),
    ):
        binary = (proof / "build" / f"tools-{mode}").resolve(strict=True)
        record = None
        try:
            # Use the already freshly linked physical kit binary. Only the
            # build step is replaced; all isolation/launch/readiness stays in
            # the existing wrapper, never an unisolated subprocess launch.
            with patch.object(isd, "build", return_value=binary):
                record = isd.start(
                    args.isd,
                    profile="ui-showcase-tools",
                    ui_debug=enabled,
                    ui_profile="showcase-v19" if enabled else None,
                    consumer_root=proof / "consumer/ui_showcase_tools",
                    kit_root=proof / "kit",
                    font=proof / "resources/font.ttf",
                    section="controls",
                    size="960x720",
                )
            run = Path(record["run"])
            log = (run / "isd" / record["id"] / "app.log").read_text()
            endpoints = [
                json.loads(line)
                for line in log.splitlines()
                if line.startswith('{"profile":"showcase-v19",')
            ]
            assert len(endpoints) == int(enabled), (mode, enabled, log)
            if enabled:
                result = subprocess.run(
                    [
                        sys.executable,
                        "-B",
                        str(ROOT / "scripts/ui-showcase-cli.py"),
                        "--socket",
                        record["ui_socket"],
                        "--profile",
                        "showcase-v19",
                        "capabilities",
                    ],
                    text=True,
                    capture_output=True,
                    timeout=5,
                )
                (output / f"{mode}-capabilities.json").write_text(result.stdout)
                assert (
                    result.returncode == 0
                    and json.loads(result.stdout)["result"]["test_time"] is False
                )
            else:
                assert "ui_socket" not in record
            image = run / f"gate-{mode}-{enabled}.png"
            captured = subprocess.run(
                [
                    sys.executable,
                    "-B",
                    str(ROOT / "scripts/ui_isd.py"),
                    "screenshot",
                    str(run),
                    "--output",
                    str(image),
                ],
                capture_output=True,
                text=True,
                timeout=30,
            )
            (output / f"{mode}-{enabled}-screenshot.log").write_text(
                captured.stdout + captured.stderr
            )
            assert captured.returncode == 0, captured.stdout + captured.stderr
            results.append(
                dict(
                    mode=mode,
                    enabled=enabled,
                    run=str(run),
                    png=str(image),
                    binary=str(binary),
                )
            )
        finally:
            if record:
                stopped = isd.stop(isd.load_record(Path(record["run"])))
                assert stopped["status"]["phase"] == "stopped"
            (output / "results.json").write_text(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
