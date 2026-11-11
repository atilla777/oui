#!/usr/bin/env python3
"""Prepare only the explicit rich fallback subset; never expand the primary."""

import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "primary", Path(__file__).with_name("prepare-font.py")
)
primary = importlib.util.module_from_spec(spec)
spec.loader.exec_module(primary)

POINTS = {0x20, 0x301, 0x3B1, 0x3A9, 0x3AC, 0x221E}


def build(archive):
    config = primary.settings()
    config.update(
        family="Slyx Rich Fallback", postscript_name="SlyxRichFallback-Regular"
    )
    return primary.build(config, archive, POINTS)


if __name__ == "__main__":
    import argparse
    import hashlib

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if primary.fontTools.__version__ != primary.settings()["fonttools_version"]:
        raise ValueError("use pinned FontTools")
    data = build(args.archive)
    target = primary.FONT_DIR / "slyx-rich-fallback.ttf"
    if args.check:
        if target.read_bytes() != data:
            raise ValueError("fallback subset is not reproducible")
    else:
        target.write_bytes(data)
    print(
        f"Rich fallback OK: {len(data)} bytes, SHA-256 {hashlib.sha256(data).hexdigest()}"
    )
