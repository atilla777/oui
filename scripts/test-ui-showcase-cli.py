#!/usr/bin/env python3
"""Deterministic client tests; no application display or supervisor."""

import json
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import threading
import unittest
import importlib.util
import copy

CLI = Path(__file__).with_name("ui-showcase-cli.py")
SPEC = importlib.util.spec_from_file_location("showcase_cli", CLI)
CLIENT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CLIENT)


class ClientTests(unittest.TestCase):
    def test_exact_counter_and_strict_envelope_oracles(self):
        request = dict(request_id="precise", op="list-sections")
        reply = self.reply(request)
        reply["frame_id"] = (1 << 64) - 1
        CLIENT.validate_reply(reply, request)
        for field in (
            "screen_epoch",
            "frame_id",
            "model_revision",
            "published_revision",
        ):
            for invalid in (-1, 1 << 64, 1.0, True, "2"):
                with (
                    self.subTest(field=field, invalid=invalid),
                    self.assertRaises(ValueError),
                ):
                    CLIENT.validate_reply(dict(reply, **{field: invalid}), request)
        for changed in (
            dict(reply, protocol=18),
            dict(reply, surprise=1),
            dict(reply, request_id="other"),
            dict(reply, historical=True),
            dict(reply, ok=False),
            dict(reply, result=[]),
            dict(reply, error=dict(code="", phase="published_frame")),
        ):
            with self.assertRaises(ValueError):
                CLIENT.validate_reply(changed, request)
        minimal = dict(
            protocol=19,
            request_id="precise",
            ok=False,
            error=dict(code="Forbidden", id="", phase="request"),
        )
        CLIENT.validate_reply(minimal, request)
        with self.assertRaises(ValueError):
            CLIENT.validate_reply(dict(minimal, request_id=""), request)

    def test_schema_failure_does_not_resend_and_inputs_refuse_before_connect(self):
        result, requests, _ = self.exchange(
            lambda r: dict(self.reply(r), frame_id=1.5), "activate", "button"
        )
        self.assertEqual(result.returncode, 2)
        self.assertEqual(len(requests), 1)
        for arguments in (
            ("scroll", "region", "--delta-y", "nan"),
            ("advance-hold", "--duration-ms", "-1"),
            ("advance-hold", "--duration-ms", str(1 << 63)),
        ):
            result = subprocess.run(
                [
                    sys.executable,
                    "-B",
                    str(CLI),
                    "--socket",
                    "/no/discovery/allowed",
                    "--profile",
                    "showcase-v19",
                    *arguments,
                ],
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 2)
            self.assertNotIn("unknown outcome", result.stderr)

    def exchange(self, responder, *arguments):
        with tempfile.TemporaryDirectory(
            prefix="iv15-cli-", dir="/tmp/opencode"
        ) as directory:
            endpoint = str(Path(directory) / "ui.sock")
            listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            listener.bind(endpoint)
            listener.listen(1)
            listener.settimeout(3)
            requests = []
            failures = []

            def serve():
                try:
                    connection, _ = listener.accept()
                    with connection:
                        connection.settimeout(2)
                        line = b""
                        while not line.endswith(b"\n"):
                            chunk = connection.recv(65536)
                            if not chunk:
                                break
                            line += chunk
                        request = json.loads(line)
                        requests.append(request)
                        response = responder(request)
                        if response is not None:
                            connection.sendall(
                                json.dumps(response, ensure_ascii=False).encode()
                                + b"\n"
                            )
                except (OSError, ValueError) as error:
                    failures.append(str(error))

            worker = threading.Thread(target=serve)
            worker.start()
            try:
                result = subprocess.run(
                    [
                        sys.executable,
                        "-B",
                        str(CLI),
                        "--socket",
                        endpoint,
                        "--profile",
                        "showcase-v19",
                        *arguments,
                    ],
                    capture_output=True,
                    text=True,
                    timeout=5,
                )
            finally:
                worker.join(timeout=4)
                listener.close()
            return result, requests, failures

    @staticmethod
    def payload(op):
        observation = dict(
            selected_section="controls",
            locale="en",
            scale=1,
            pixel_perfect=False,
            effects=0,
            values=[],
            unsupported=[],
            last_action=None,
        )
        action = dict(
            dispatch=dict(
                code="Applied",
                target="button",
                source="Agent",
                sequence=1,
                has_event=True,
            ),
            application=dict(status="applied", reason=""),
            effects_before=0,
            effects_after=1,
            observation=observation,
        )
        rect = dict(x=0, y=0, w=10, h=10)
        node = dict(
            id="button",
            parent_id="",
            children=[],
            structural_role="Leaf",
            role="button",
            name="Button",
            text="Button",
            bounds=rect,
            content=rect,
            clip=rect,
            paint_clip=rect,
            visible=True,
            enabled=True,
            focused=False,
            hovered=False,
            pressed=False,
            availability="Applied",
            actions=[],
            unsupported=[],
        )
        if op == "capabilities":
            return dict(
                operations=["tree"], unsupported=[], test_time=False, section="controls"
            )
        if op == "list-sections":
            return dict(
                sections=[
                    dict(
                        id="controls",
                        group="gallery",
                        name="Controls",
                        fixture="minimal",
                        status="experimental",
                        limitations="",
                        resources_available=True,
                        resource_reason="",
                    )
                ]
            )
        if op == "tree":
            return dict(nodes=[node], observation=observation)
        if op == "find":
            return dict(ids=["button"])
        if op == "inspect":
            return dict(node=node)
        if op == "geometry":
            return dict(
                id="button",
                bounds=rect,
                content=rect,
                clip=rect,
                paint_clip=rect,
                drawable=dict(w=960, h=720),
                ui_scale=1,
            )
        if op in ("diagnostics", "assert-no-errors"):
            return dict(diagnostics=[], strict_ok=True)
        if op == "snapshot":
            return dict(
                path="/own/run/snapshot-1",
                manifest="snapshot.json",
                image="screenshot.bmp",
            )
        if op == "select-section":
            action["selection"] = dict(
                requested="controls", current="controls", status="applied"
            )
        return action

    @staticmethod
    def reply(request, ok=True, error=""):
        return dict(
            protocol=19,
            request_id=request["request_id"],
            ok=ok,
            error=dict(code=error, id="", phase="published_frame"),
            ready=True,
            historical=False,
            section="controls",
            screen_epoch=1,
            frame_id=2,
            model_revision=0,
            published_revision=0,
            result=ClientTests.payload(request.get("op", "activate")) if ok else None,
        )

    def test_missing_operation_result_is_unknown_and_never_retried(self):
        for arguments in (
            ("activate", "button"),
            ("snapshot",),
            ("tree",),
            ("list-sections",),
        ):
            with self.subTest(arguments=arguments):
                result, requests, _ = self.exchange(
                    lambda r: dict(self.reply(r), result={}), *arguments
                )
                self.assertEqual(result.returncode, 2, result.stdout)
                self.assertIn("unknown outcome", result.stderr)
                self.assertEqual(len(requests), 1)

    def test_nested_observation_node_section_geometry_and_snapshot_schema(self):
        for op, path, bad in (
            ("tree", ["nodes", 0, "enabled"], "yes"),
            ("tree", ["observation", "last_action"], {}),
            ("tree", ["observation", "values"], [dict(id="x", value=None)]),
            ("inspect", ["node", "children"], [1]),
            ("geometry", ["ui_scale"], float("nan")),
            ("list-sections", ["sections", 0, "resources_available"], 1),
            ("diagnostics", ["strict_ok"], 1),
            ("snapshot", ["path"], 42),
            ("snapshot", ["manifest"], "other.json"),
        ):
            request = dict(request_id="nested", op=op)
            reply = self.reply(request)
            current = reply["result"]
            for key in path[:-1]:
                current = current[key]
            current[path[-1]] = bad
            with self.subTest(op=op, path=path), self.assertRaises(ValueError):
                CLIENT.validate_reply(reply, request)
        # A known effect remains typed even if its publication failed.
        request = dict(request_id="failed", op="activate")
        reply = self.reply(request, False, "Not_Ready")
        reply["result"] = self.payload("activate")
        CLIENT.validate_reply(reply, request)
        reply["result"]["dispatch"]["sequence"] = 1.5
        with self.assertRaises(ValueError):
            CLIENT.validate_reply(reply, request)

    def test_every_operation_shape_and_nested_types(self):
        operations = (
            "capabilities",
            "list-sections",
            "select-section",
            "tree",
            "find",
            "inspect",
            "geometry",
            "diagnostics",
            "assert-no-errors",
            "snapshot",
            "focus",
            "navigate",
            "activate",
            "cancel",
            "scroll",
            "begin-hold",
            "advance-hold",
            "release-hold",
            "cancel-hold",
        )
        for op in operations:
            request = dict(request_id="schema", op=op)
            valid = self.reply(request)
            CLIENT.validate_reply(valid, request)
            for key in valid["result"]:
                malformed = copy.deepcopy(valid)
                del malformed["result"][key]
                with self.subTest(op=op, missing=key), self.assertRaises(ValueError):
                    CLIENT.validate_reply(malformed, request)
        for path, bad in (
            (["dispatch", "sequence"], True),
            (["dispatch", "has_event"], 1),
            (["application", "status"], "success"),
            (["effects_after"], 1.5),
            (["observation", "values"], {}),
            (["observation", "effects"], -1),
        ):
            request = dict(request_id="schema", op="activate")
            malformed = self.reply(request)
            current = malformed["result"]
            for key in path[:-1]:
                current = current[key]
            current[path[-1]] = bad
            with self.subTest(path=path), self.assertRaises(ValueError):
                CLIENT.validate_reply(malformed, request)

    def test_own_profile_envelope_and_success(self):
        result, requests, failures = self.exchange(self.reply, "list-sections")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(failures, [])
        self.assertEqual(len(requests), 1)
        self.assertEqual(requests[0]["protocol"], 19)
        self.assertEqual(requests[0]["op"], "list-sections")

    def test_structured_refusal_is_one_not_unknown(self):
        result, requests, _ = self.exchange(
            lambda r: self.reply(r, False, "Disabled"), "activate", "button"
        )
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(len(requests), 1)

    def test_disconnect_or_correlation_failure_never_resends(self):
        for responder in (
            lambda r: None,
            lambda r: dict(self.reply(r), request_id="wrong"),
        ):
            result, requests, _ = self.exchange(responder, "activate", "button")
            self.assertEqual(result.returncode, 2, result.stderr)
            self.assertEqual(len(requests), 1)
            self.assertIn("unknown", result.stderr.lower())


if __name__ == "__main__":
    unittest.main()
