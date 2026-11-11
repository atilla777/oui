#!/usr/bin/env python3
"""Export the maintained oui allowlist to a fresh disposable proof/vendor root.

No compiler, download, installation or dependency update. Exported copies are
read-only inputs, not another maintained source. Git metadata is never copied.
"""

import argparse
import hashlib
import json
from pathlib import Path
import shutil

SOURCE = Path(__file__).resolve().parents[1]


def export(destination):
    destination = Path(destination)
    if destination.exists() or destination.is_symlink():
        raise ValueError("output already exists; choose a fresh directory")
    inventory = json.loads((SOURCE / "inventory.json").read_text())
    destination.mkdir(parents=True)
    for name, item in inventory["files"].items():
        source = SOURCE / name
        if (
            source.is_symlink()
            or not source.is_file()
            or not source.resolve().is_relative_to(SOURCE)
        ):
            raise ValueError(f"not a regular contained source: {name}")
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        shutil.copymode(source, target)
        item["sha256"] = hashlib.sha256(target.read_bytes()).hexdigest()
        item["mode"] = oct(target.stat().st_mode & 0o777)
    (destination / "inventory.json").write_text(
        json.dumps(inventory, indent=2, ensure_ascii=False) + "\n"
    )
    return destination


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    print(export(parser.parse_args().destination.resolve()))
