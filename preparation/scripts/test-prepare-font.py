#!/usr/bin/env python3
"""Offline regression checks for the font resource and preparation contract."""

import importlib.util
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location(
    "prepare_font", Path(__file__).with_name("prepare-font.py")
)
FONT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(FONT)


class FontTests(unittest.TestCase):
    def test_shipped_font_covers_every_text_and_icon(self):
        with FONT.TTFont(FONT.FONT_TARGET) as font:
            FONT.check_coverage(font, FONT.required_codepoints(FONT.settings()))
            self.assertEqual(font["name"].getDebugName(1), "Slyx UI")
            self.assertIn(0xF500, font.getBestCmap())

    def test_missing_translation_character_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix="slyx-font-test-") as directory:
            path = Path(directory)
            (path / "new.ru.txt").write_text("Новый текст \U0001f40d", encoding="utf-8")
            points = FONT.required_codepoints(FONT.settings(), text_dir=path)
            with FONT.TTFont(FONT.FONT_TARGET) as font:
                with self.assertRaisesRegex(ValueError, "U\\+1F40D"):
                    FONT.check_coverage(font, points)

    def test_missing_icon_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix="slyx-font-test-") as directory:
            path = Path(directory) / "icons.json"
            path.write_text('{"unshipped": "F04B"}', encoding="utf-8")
            points = FONT.required_codepoints(FONT.settings(), icons_path=path)
            with FONT.TTFont(FONT.FONT_TARGET) as font:
                with self.assertRaisesRegex(ValueError, "U\\+F04B"):
                    FONT.check_coverage(font, points)

    def test_unicode_whitespace_inside_text_is_not_ignored(self):
        with tempfile.TemporaryDirectory(prefix="slyx-font-test-") as directory:
            path = Path(directory)
            (path / "spacing.en.txt").write_text("A\u2003B", encoding="utf-8")
            points = FONT.required_codepoints(FONT.settings(), text_dir=path)
            self.assertIn(0x2003, points)
            with FONT.TTFont(FONT.FONT_TARGET) as font:
                with self.assertRaisesRegex(ValueError, "U\\+2003"):
                    FONT.check_coverage(font, points)

    def test_changed_source_archive_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix="slyx-font-test-") as directory:
            archive = Path(directory) / "wrong.tar.xz"
            archive.write_bytes(b"not the pinned source")
            with self.assertRaisesRegex(ValueError, "SHA-256 mismatch"):
                FONT.build(FONT.settings(), archive, {65})


if __name__ == "__main__":
    unittest.main()
