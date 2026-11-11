#!/usr/bin/env python3
"""UI wrapper regression tests. No live display or agent invocation."""

import importlib.util
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "ui_isd", Path(__file__).with_name("ui_isd.py")
)
ui = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ui)


class BuildIdentity(unittest.TestCase):
    def test_tools_metadata_uses_actual_oui_root_not_invoking_project(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            oui = root / "oui"
            consumer = oui / "consumer/ui_showcase_tools"
            kit = oui / "kit"
            foreign = root / "invoking-app"
            run = root / "run"
            for p in (consumer, kit, foreign, run):
                p.mkdir(parents=True)
            (oui / ".git").write_text("gitdir: fixture")
            (oui / "inventory.json").write_text('{"files": {}}')
            commands = []

            def output(args, **kwargs):
                if args[0] == "pkg-config":
                    return "-lpng16 -lz"
                correct = Path(kwargs["cwd"]) == oui
                if "--show-toplevel" in args:
                    return str(oui) + "\n"
                if "HEAD" in args:
                    return "actual-oui\n" if correct else "wrong-parent\n"
                return "" if correct else " M unrelated\n"

            def compile(args, **kwargs):
                commands.append(args)
                binary = run / "ui"
                binary.write_text("fixture")
                binary.chmod(0o700)
                return subprocess.CompletedProcess(args, 0)

            with (
                patch.object(ui.subprocess, "check_output", side_effect=output),
                patch.object(ui.subprocess, "run", side_effect=compile),
                patch.object(ui.shutil, "which", return_value="odin"),
            ):
                ui.build(
                    foreign,
                    run,
                    "ui-showcase-tools",
                    consumer_root=consumer,
                    kit_root=kit,
                )
            self.assertIn("-define:UI_BUILD_REVISION=actual-oui", commands[0])
            self.assertIn("-define:UI_BUILD_DIRTY=false", commands[0])
            self.assertTrue(
                (run / "build.json").is_file(),
                "build must retain source/binary/command metadata",
            )
            metadata = json.loads((run / "build.json").read_text())
            self.assertEqual(metadata["revision"], "actual-oui")
            self.assertFalse(metadata["dirty"])
            self.assertEqual(
                metadata["binary_sha256"],
                hashlib.sha256((run / "ui").read_bytes()).hexdigest(),
            )

    def test_no_implicit_isd_discovery(self):
        with (
            patch.dict(os.environ, {}, clear=True),
            patch.object(ui.subprocess, "run") as command,
        ):
            with self.assertRaisesRegex(RuntimeError, "Explicit"):
                ui.find_isd()
            command.assert_not_called()

    def test_policy_marker_or_executable_alone_cannot_pass_full_source_preflight(self):
        with tempfile.TemporaryDirectory() as directory:
            binary = Path(directory) / "isd"
            binary.write_text("#!/bin/sh\n# linux-abstract-v1\nexit 0\n")
            binary.chmod(0o700)
            with self.assertRaisesRegex(RuntimeError, "whole|source|verified"):
                ui.find_isd(binary)

    def test_proof_identity_is_bound_to_inventory_bytes_and_not_parent_git(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "kit").mkdir()
            data = b"selected bytes"
            (root / "kit/selected.odin").write_bytes(data)
            inventory = json.dumps(
                {
                    "files": {
                        "kit/selected.odin": {
                            "sha256": hashlib.sha256(data).hexdigest()
                        }
                    }
                }
            ).encode()
            (root / "inventory.json").write_bytes(inventory)
            with patch.object(ui.subprocess, "check_output") as git:
                revision, dirty = ui.source_identity(root / "kit")
                self.assertEqual(
                    revision, "inventory-" + hashlib.sha256(inventory).hexdigest()
                )
                self.assertFalse(dirty)
                (root / "kit/selected.odin").write_bytes(b"changed bytes")
                self.assertEqual(
                    ui.source_identity(root / "kit"), ("unavailable", True)
                )
                git.assert_not_called()


class Isolation(unittest.TestCase):
    def test_every_selected_module_and_native_input_capability_is_checked(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "isdlib").mkdir()
            (root / "isd").write_bytes(b"entry")
            module = root / "isdlib/selected.py"
            module.write_bytes(b"module")
            expected = {
                str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in (root / "isd", module)
            }
            with patch.object(ui, "ISD_CODE_PINS", (("fixture", False, expected),)):
                self.assertEqual(ui.verify_isd(root / "isd")["files"], expected)
                with self.assertRaisesRegex(RuntimeError, "native"):
                    ui.verify_isd(root / "isd", native_input=True)
                module.write_bytes(b"modified module")
                with self.assertRaisesRegex(RuntimeError, "whole source"):
                    ui.verify_isd(root / "isd")

    def test_missing_live_policy_stops_input_before_transport(self):
        record = {
            "isd": "/fixture/isd",
            "root": "/fixture/run/isd",
            "id": "a" * 32,
            "isd_source": {"files": {}},
        }
        response = {
            "protocol": 1,
            "ok": True,
            "id": record["id"],
            "supervisor_alive": True,
            "xvfb_alive": True,
        }
        with (
            patch.object(ui, "verify_isd", return_value=record["isd_source"]),
            patch.object(
                ui.subprocess,
                "run",
                return_value=subprocess.CompletedProcess([], 0, json.dumps(response)),
            ) as transport,
        ):
            with self.assertRaisesRegex(RuntimeError, "display_allocation"):
                ui.call(record, "key", record["id"], "tap", "Return")
            self.assertEqual(transport.call_count, 1)
            self.assertIn("status", transport.call_args.args[0])

    def start_fixture(self, failure=None, missing_policy=False, check=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            consumer, kit, run = root / "consumer", root / "kit", root / "run"
            for p in (consumer, kit, run):
                p.mkdir()
            font, binary = root / "font.ttf", root / "binary"
            font.write_bytes(b"explicit resource")
            binary.write_bytes(b"prebuilt UI")
            commands = []

            def transport(record, *args):
                commands.append(args[0])
                if args[0] == "create":
                    result = {"id": "a" * 32}
                    if not missing_policy:
                        result["display_allocation"] = "linux-abstract-v1"
                    return result
                return {}

            manifest = {"revision": "fixture", "files": {}}
            with (
                patch.object(ui, "find_isd", return_value=root / "isd"),
                patch.object(ui, "verify_isd", return_value=manifest),
                patch.object(ui, "build", return_value=binary),
                patch.object(ui.tempfile, "mkdtemp", return_value=str(run)),
                patch.object(ui, "call", side_effect=transport),
                patch.object(
                    ui, "wait_ready", side_effect=failure, return_value="window-1"
                ),
                patch.object(ui, "wait_exit", return_value={"app_exit": 0}),
                patch.object(ui, "stop", return_value={"phase": "stopped"}) as stop,
            ):
                kwargs = dict(
                    consumer_root=consumer, kit_root=kit, font=font, check=check
                )
                if failure or missing_policy:
                    with self.assertRaises(RuntimeError):
                        ui.start(root / "isd", **kwargs)
                    self.assertEqual(stop.call_count, 1)
                    saved = json.loads((run / "run.json").read_text())
                    self.assertFalse(saved["ready"])
                    self.assertIn("error", saved)
                else:
                    result = ui.start(root / "isd", **kwargs)
                    if not check:
                        self.assertTrue(result["ready"])
                        stop.assert_not_called()
                    else:
                        stop.assert_called_once()
                return commands

    def test_missing_create_policy_stops_own_id_without_launch(self):
        self.assertEqual(self.start_fixture(missing_policy=True), ["create"])

    def test_readiness_failure_preserves_error_and_stops(self):
        self.assertEqual(
            self.start_fixture(failure=RuntimeError("readiness failure")),
            ["create", "launch"],
        )

    def test_normal_start_never_focuses_implicitly_and_check_stops(self):
        self.assertEqual(self.start_fixture(), ["create", "launch"])
        self.assertEqual(self.start_fixture(check=True), ["create", "launch"])

    def test_unknown_source_is_refused_before_build_or_create(self):
        with (
            patch.object(
                ui, "find_isd", side_effect=RuntimeError("whole source refused")
            ),
            patch.object(ui, "build") as build,
            patch.object(ui, "call") as command,
        ):
            with self.assertRaisesRegex(RuntimeError, "whole source"):
                ui.start(
                    "/fixture/isd",
                    consumer_root=ui.PROJECT / "consumer/standalone_menu",
                    kit_root=ui.PROJECT / "kit",
                    font=ui.PROJECT / "resources/font.ttf",
                )
            build.assert_not_called()
            command.assert_not_called()


if __name__ == "__main__":
    unittest.main()
