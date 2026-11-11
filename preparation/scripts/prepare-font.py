#!/usr/bin/env python3
"""Rebuild or check the shipped UI font. Never downloads or installs anything."""

import argparse
import hashlib
import io
import json
from pathlib import Path
import sys
import tarfile

import fontTools
from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent.parent
FONT_DIR = ROOT / "assets/fonts"


def settings():
    return json.loads((FONT_DIR / "source.json").read_text(encoding="utf-8"))


def required_codepoints(config, text_dir=None, icons_path=None):
    points = set(config["baseline_codepoints"])
    for start, end in config["baseline_ranges"]:
        points.update(range(start, end + 1))
    text_dir = text_dir or ROOT / "assets/text"
    texts = sorted(text_dir.glob("*.txt"))
    if not texts:
        raise ValueError("no UI text resources found")
    for path in texts:
        # Line endings are not rendered; other whitespace is a real glyph.
        points.update(
            ord(c) for c in path.read_text(encoding="utf-8") if c not in "\r\n"
        )
    icons = json.loads(
        (icons_path or FONT_DIR / "icons.json").read_text(encoding="utf-8")
    )
    points.update(int(code, 16) for code in icons.values())
    if any(not 0 <= point <= 0x10FFFF or 0xD800 <= point <= 0xDFFF for point in points):
        raise ValueError("invalid Unicode scalar in the requested subset")
    return points


def check_coverage(font, points):
    missing = points - set(font.getBestCmap() or {})
    if missing:
        raise ValueError(
            "font lacks: " + ", ".join(f"U+{p:04X}" for p in sorted(missing))
        )


def build(config, archive, points):
    data = archive.read_bytes()
    if hashlib.sha256(data).hexdigest() != config["archive_sha256"]:
        raise ValueError("source archive SHA-256 mismatch")
    # Read only the named regular member; never extract archive-controlled paths.
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:xz") as package:
        member = package.getmember(config["member"])
        if not member.isfile():
            raise ValueError("source font is not a regular archive member")
        with package.extractfile(member) as stream:
            source = stream.read()
        if hashlib.sha256(source).hexdigest() != config["member_sha256"]:
            raise ValueError("source font SHA-256 mismatch")
        font = TTFont(io.BytesIO(source), recalcTimestamp=False)
    check_coverage(font, points)
    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.name_languages = ["*"]
    options.name_legacy = True
    options.recalc_timestamp = False
    # The obsolete FontForge timestamp table has no runtime use.
    options.drop_tables += ["FFTM", "PfEd"]
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(unicodes=points)
    subsetter.subset(font)
    # A modified derivative gets its own names; retain copyright/license records.
    names = {
        1: config["family"],
        2: "Regular",
        3: config["postscript_name"],
        4: config["family"] + " Regular",
        6: config["postscript_name"],
        16: config["family"],
        17: "Regular",
    }
    for name_id, value in names.items():
        font["name"].removeNames(nameID=name_id)
        font["name"].setName(value, name_id, 3, 1, 0x409)
    output = io.BytesIO()
    font.save(output, reorderTables=True)
    font.close()
    return output.getvalue()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, help="pinned source tar.xz for rebuild")
    parser.add_argument("--check", action="store_true", help="check without writing")
    args = parser.parse_args()
    config = settings()
    if fontTools.__version__ != config["fonttools_version"]:
        raise ValueError(
            "use the pinned FontTools version in fonttools-requirements.txt"
        )
    if not args.check and not args.archive:
        parser.error(
            "a rebuild requires --archive; use --check for offline coverage validation"
        )
    points = required_codepoints(config)
    target = FONT_DIR / "slyx-ui.ttf"
    if args.archive:
        result = build(config, args.archive, points)
        if args.check:
            if target.read_bytes() != result:
                raise ValueError(
                    "shipped TTF differs from the reproducible subset; rebuild it"
                )
        else:
            target.write_bytes(result)
    with TTFont(target, recalcTimestamp=False) as font:
        check_coverage(font, points)
    print(
        f"Font OK: {len(points)} required codepoints, {target.stat().st_size} bytes, "
        f"SHA-256 {hashlib.sha256(target.read_bytes()).hexdigest()}"
    )


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, tarfile.TarError) as error:
        print(f"Font preparation failed: {error}", file=sys.stderr)
        sys.exit(1)
