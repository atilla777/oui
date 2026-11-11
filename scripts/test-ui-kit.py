#!/usr/bin/env python3
"""Static distribution assertions; build/recipes remain in the existing proof scripts."""

import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(os.environ["UI_KIT_ROOT"]).resolve()


class Distribution(unittest.TestCase):
    def test_qualification_fixtures_are_portable_test_inputs(self):
        inventory = json.loads((ROOT / "inventory.json").read_text())["files"]
        for path in [
            "tests/ui_recipes/native_fixture/fixture.odin",
            "consumer/standalone_menu/qualification/main.odin",
            "consumer/ui_showcase/qualification/main.odin",
            *[
                f"tests/ui_recipes/{name}/native/main.odin"
                for name in ("hud", "settings", "inventory")
            ],
        ]:
            self.assertTrue((ROOT / path).is_file(), path)
            self.assertEqual(inventory[path]["role"], "test")

    def test_forbidden_runtime_import_stops_before_tools_build(self):
        # Test the proof script's refusal, not compiler/link/display behavior.
        with tempfile.TemporaryDirectory(prefix="ui-kit-guard-") as directory:
            root = Path(directory)
            for name in (
                "scripts",
                "kit",
                "consumer",
                "resources",
                "tests",
                "preparation",
                "bin",
            ):
                (root / name).mkdir()
            (root / "inventory.json").write_text("{}")
            shutil.copyfile(
                ROOT / "scripts/test-ui-showcase", root / "scripts/test-ui-showcase"
            )
            compiler = root / "bin/odin"
            compiler.write_text("""#!/bin/bash
printf '%s\\n' "$*" >> "$UI_GUARD_TRACE"
echo '"/physical/kit/ui_debug/"'
for arg; do
  if [[ $arg == -out:* ]]; then
    target=${arg#-out:}
    printf '#!/bin/bash\\nexit 1\\n' > "$target"
    chmod +x "$target"
  fi
done
""")
            compiler.chmod(0o755)
            trace = root / "trace"
            result = subprocess.run(
                ["bash", "scripts/test-ui-showcase", "--portable-check"],
                cwd=root,
                env=dict(
                    os.environ,
                    PATH=str(root / "bin") + ":" + os.environ["PATH"],
                    UI_GUARD_TRACE=str(trace),
                ),
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn(
                "consumer/ui_showcase_tools",
                trace.read_text(),
                "forbidden import must stop immediately",
            )

    def test_portable_entry_and_skill(self):
        for name in (
            "README",
            "quickstart",
            "api",
            "lifecycle",
            "recipes",
            "compatibility",
            "resources",
            "provenance",
        ):
            self.assertTrue((ROOT / "docs" / (name + ".md")).is_file(), name)
        skill = (ROOT / "skills/odin-ui/SKILL.md").read_text()
        self.assertIn("name: odin-ui", skill)
        self.assertNotIn("kit/ui/", skill)
        self.assertIn("Permission", (ROOT / "LICENSE").read_text())

    def test_inventory_covers_every_supplied_file(self):
        inventory = json.loads((ROOT / "inventory.json").read_text())
        files = {
            str(p.relative_to(ROOT))
            for p in ROOT.rglob("*")
            if p.is_file()
            and p.name != "inventory.json"
            and ".git" not in p.relative_to(ROOT).parts
            and "__pycache__" not in p.relative_to(ROOT).parts
            and "build" not in p.relative_to(ROOT).parts
        }
        self.assertEqual(files, set(inventory["files"]))
        for path, item in inventory["files"].items():
            p = ROOT / path
            self.assertFalse(p.is_symlink(), path)
            self.assertEqual(
                hashlib.sha256(p.read_bytes()).hexdigest(), item["sha256"], path
            )
            self.assertTrue((ROOT / item["license"]).is_file(), path)
            self.assertIn(
                item["role"],
                ("runtime", "build", "preparation", "test", "documentation"),
            )

    def test_portable_links(self):
        for folder in (ROOT / "docs", ROOT / "skills", ROOT / "README.md"):
            for p in [folder] if folder.is_file() else folder.rglob("*.md"):
                for target in re.findall(r"\]\(([^)]+)\)", p.read_text()):
                    if "://" in target or target.startswith("#"):
                        continue
                    target = target.split("#")[0]
                    resolved = (p.parent / target).resolve()
                    self.assertTrue(resolved.is_relative_to(ROOT), (p, target))
                    self.assertTrue(resolved.exists(), (p, target))


if __name__ == "__main__":
    unittest.main()
