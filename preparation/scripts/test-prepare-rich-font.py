#!/usr/bin/env python3
import importlib.util
import io
import sys
import unittest
from pathlib import Path
from fontTools.ttLib import TTFont

spec = importlib.util.spec_from_file_location(
    "rich", Path(__file__).with_name("prepare-rich-font.py")
)
rich = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rich)
ARCHIVE = Path(sys.argv.pop())


class RichFontTests(unittest.TestCase):
    def test_explicit_fallback_cmap_and_reproducibility(self):
        one = rich.build(ARCHIVE)
        self.assertEqual(one, rich.build(ARCHIVE))
        with TTFont(io.BytesIO(one)) as font:
            self.assertTrue(rich.POINTS <= set(font.getBestCmap()))
            self.assertEqual(font["name"].getDebugName(1), "Slyx Rich Fallback")
            self.assertIsNotNone(font["name"].getDebugName(13))
        with TTFont(rich.primary.FONT_TARGET) as primary:
            self.assertTrue({0x3B1, 0x3A9, 0x3AC}.isdisjoint(primary.getBestCmap()))


unittest.main()
