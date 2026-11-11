"""Offline original geometric atlas authoring; never imported by the runtime."""

import json
import pathlib
import struct
import zlib

ROOT = pathlib.Path(__file__).resolve().parents[1] / "assets"


def chunk(kind, data):
    return (
        struct.pack(">I", len(data))
        + kind
        + data
        + struct.pack(">I", zlib.crc32(kind + data))
    )


def make(alternate):
    width, height = 256, 128
    pixels = bytearray(width * height * 4)
    regions = []

    def region(name, rect, color, nine=None, pivot=None):
        x, y, w, h = rect
        for yy in range(h):
            for xx in range(w):
                edge = min(xx, yy, w - 1 - xx, h - 1 - yy) < 2
                stripe = alternate and (xx + yy) % 7 < 2
                rgb = tuple(
                    max(0, c - 45) if edge else min(255, c + 25) if stripe else c
                    for c in color
                )
                at = ((y + yy) * width + x + xx) * 4
                pixels[at : at + 4] = bytes((*rgb, 255))
        item = {"id": name, "page": "geometry", "rect": rect}
        if nine is not None:
            item["nine_slice"] = nine
        if pivot is not None:
            item["pivot"] = pivot
        regions.append(item)

    def nine(mode="stretch", empty=False):
        return {
            "border": [4, 4, 4, 4],
            "texture_scale": 1,
            "edges": mode,
            "center_x": mode,
            "center_y": mode,
            "omit_center": empty,
            "padding": {"left": 6, "top": 4, "right": 6, "bottom": 4},
        }

    region(
        "panel",
        [200 if alternate else 0, 0, 32, 32],
        (90, 100, 135) if alternate else (155, 170, 185),
        nine(),
    )
    colors = [
        (100, 175, 210),
        (130, 205, 235),
        (60, 125, 165),
        (150, 185, 240),
        (120, 130, 140),
        (110, 205, 145),
    ]
    states = [
        "button",
        "button-hovered",
        "button-pressed",
        "button-focused",
        "button-disabled",
        "button-selected",
    ]
    for index, (name, color) in enumerate(zip(states, colors)):
        if alternate:
            color = tuple(reversed(color))
        region(
            name, [40 * (5 - index if alternate else index), 40, 32, 20], color, nine()
        )
    region(
        "placeholder", [0, 72, 24, 24], (200, 125, 200) if alternate else (210, 160, 90)
    )
    for index, name in enumerate(["close", "check", "info", "arrow"]):
        rect = [
            40 + index * 32,
            72,
            20 if alternate and name == "info" else 16,
            12 if alternate and name == "info" else 16,
        ]
        region(
            name,
            rect,
            (205, 180, 80) if alternate else (60, 150, 160),
            pivot=([1, 0] if alternate else [0.5, 0.5]) if name == "info" else None,
        )
        x, y, w, h = rect
        for yy in range(3, h - 3):
            for xx in range(3, w - 3):
                ink = (
                    (xx == yy or xx + yy == w - 1)
                    if name == "close"
                    else (
                        (3 <= xx <= 6 and yy == xx + 4)
                        or (6 <= xx <= 12 and yy == 16 - xx)
                    )
                    if name == "check"
                    else (xx == w // 2 and (yy == 3 or yy >= 6))
                    if name == "info"
                    else (xx == w // 2 + abs(yy - h // 2))
                )
                if ink:
                    at = ((y + yy) * width + x + xx) * 4
                    pixels[at : at + 4] = bytes((245, 245, 245, 255))
    base = next(item["rect"] for item in regions if item["id"] == "button")
    for name, mode, empty in [
        ("slice-stretch", "stretch", False),
        ("slice-repeat", "repeat", False),
        ("slice-empty", "repeat", True),
    ]:
        regions.append(
            {
                "id": name,
                "page": "geometry",
                "rect": base,
                "nine_slice": nine(mode, empty),
            }
        )
    raw = b"".join(
        b"\0" + pixels[y * width * 4 : (y + 1) * width * 4] for y in range(height)
    )
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw))
        + chunk(b"IEND", b"")
    )
    target = ROOT / ("b" if alternate else "a")
    target.mkdir(parents=True, exist_ok=True)
    (target / "geometry.png").write_bytes(png)
    (target / "manifest.json").write_text(
        json.dumps(
            {
                "version": 1,
                "pages": [{"id": "geometry", "file": "geometry.png"}],
                "regions": regions,
            },
            indent=2,
        )
        + "\n"
    )


if __name__ == "__main__":
    make(False)
    make(True)
