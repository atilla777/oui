#!/usr/bin/env python3
"""Explicit showcase-v19 client. One connection/request, never retry mutations."""

import argparse
import json
import math
import socket
import sys
import uuid

LIMIT = 1024 * 1024
U64_MAX = (1 << 64) - 1


def finite(value):
    number = float(value)
    if not math.isfinite(number):
        raise argparse.ArgumentTypeError("must be finite")
    return number


def duration(value):
    if not value.isascii() or not value.isdecimal():
        raise argparse.ArgumentTypeError("must be a nonnegative integer")
    number = int(value)
    if number > (1 << 63) - 1:
        raise argparse.ArgumentTypeError("duration exceeds i64")
    return number


def nonempty(value):
    if not value or "\0" in value:
        raise argparse.ArgumentTypeError("must be nonempty and contain no NUL")
    value.encode("utf-8", errors="strict")
    return value


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--socket", required=True, type=nonempty)
    result.add_argument("--profile", required=True, choices=["showcase-v19"])
    result.add_argument("--request-id", type=nonempty)
    commands = result.add_subparsers(dest="op", required=True)
    for name in (
        "capabilities",
        "list-sections",
        "tree",
        "diagnostics",
        "assert-no-errors",
        "cancel",
        "release-hold",
        "cancel-hold",
        "snapshot",
        "set_value",
        "drag",
        "overlays",
        "crop",
        "finish-transitions",
    ):
        commands.add_parser(name)
    for name in ("inspect", "geometry", "focus", "activate", "begin-hold"):
        commands.add_parser(name).add_argument("id", type=nonempty)
    commands.add_parser("select-section").add_argument("section", type=nonempty)
    find = commands.add_parser("find").add_mutually_exclusive_group(required=True)
    for name in ("id", "role", "name"):
        find.add_argument("--" + name, type=nonempty)
    commands.add_parser("navigate").add_argument(
        "direction", choices=["forward", "backward"]
    )
    scroll = commands.add_parser("scroll")
    scroll.add_argument("id", type=nonempty)
    scroll.add_argument("--delta-y", required=True, type=finite)
    commands.add_parser("advance-hold").add_argument(
        "--duration-ms", required=True, type=duration
    )
    return result


def object_without_duplicates(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate reply field")
        result[key] = value
    return result


def invalid_constant(value):
    raise ValueError("nonfinite JSON number: " + value)


def text(value):
    return isinstance(value, str)


def boolean(value):
    return type(value) is bool


def u64(value):
    return type(value) is int and 0 <= value <= U64_MAX


def number(value):
    return (
        type(value) is int and -sys.float_info.max <= value <= sys.float_info.max
    ) or (type(value) is float and math.isfinite(value))


def choice(*values):
    return lambda value: isinstance(value, str) and value in values


def array(check):
    def validate(value):
        return isinstance(value, list) and all(check(item) for item in value)

    return validate


def nullable(check):
    return lambda value: value is None or check(value)


def shape(required, optional=None):
    def validate(value):
        fields = required | (optional or {})
        return (
            isinstance(value, dict)
            and required.keys() <= value.keys() <= fields.keys()
            and all(fields[key](item) for key, item in value.items())
        )

    return validate


EXTENT = shape(dict(w=number, h=number))
RECT = shape(dict(x=number, y=number, w=number, h=number))
APPLICATION_STATUS = choice("none", "pending", "applied", "rejected")
RECORD = shape(
    dict(
        request_id=text,
        op=text,
        target=text,
        source=choice("Agent", "Mouse", "Keyboard", "Gamepad"),
        sequence=u64,
        screen_epoch=u64,
        dispatch_code=text,
        application_status=APPLICATION_STATUS,
        reason=text,
    )
)
OBSERVATION = shape(
    dict(
        selected_section=text,
        locale=text,
        scale=number,
        pixel_perfect=boolean,
        effects=u64,
        values=array(
            shape(
                dict(
                    id=text,
                    value=lambda v: (
                        boolean(v)
                        or text(v)
                        or (type(v) is int and -(1 << 63) <= v <= U64_MAX)
                        or (type(v) is float and math.isfinite(v))
                    ),
                )
            )
        ),
        unsupported=array(text),
        last_action=nullable(RECORD),
    )
)
ACTION_FIELDS = dict(
    dispatch=shape(
        dict(
            code=text,
            target=text,
            source=choice("Agent"),
            sequence=u64,
            has_event=boolean,
        )
    ),
    application=shape(dict(status=APPLICATION_STATUS, reason=text)),
    effects_before=u64,
    effects_after=u64,
    observation=OBSERVATION,
)
NODE = shape(
    dict(
        id=text,
        parent_id=text,
        children=array(text),
        structural_role=text,
        role=text,
        name=text,
        text=text,
        bounds=RECT,
        content=RECT,
        clip=RECT,
        paint_clip=RECT,
        visible=boolean,
        enabled=boolean,
        focused=boolean,
        hovered=boolean,
        pressed=boolean,
        availability=text,
        actions=array(
            shape(
                dict(
                    action=text,
                    capability=boolean,
                    suitable=boolean,
                    allowed=boolean,
                    reason=text,
                )
            )
        ),
        unsupported=array(text),
    ),
    dict(source_hint=text),
)
DIAGNOSTIC = shape(
    dict(
        code=text,
        id=text,
        severity=choice("Info", "Warning", "Error"),
        phase=choice("update", "published_frame"),
        expected=boolean,
        reference=text,
        detail=text,
        required=EXTENT,
        available=EXTENT,
    ),
    dict(
        source_hint=text,
        frame_id=nullable(u64),
        attempt_revision=nullable(u64),
        byte_offset=nullable(u64),
        occurrence=nullable(u64),
    ),
)
RESULT_SCHEMAS = {
    "capabilities": shape(
        dict(
            operations=array(text),
            unsupported=array(text),
            test_time=boolean,
            section=text,
        )
    ),
    "list-sections": shape(
        dict(
            sections=array(
                shape(
                    dict(
                        id=text,
                        group=text,
                        name=text,
                        fixture=text,
                        status=text,
                        limitations=text,
                        resources_available=boolean,
                        resource_reason=text,
                    )
                )
            )
        )
    ),
    "select-section": shape(
        ACTION_FIELDS
        | dict(
            selection=shape(
                dict(
                    requested=text,
                    current=text,
                    status=choice("unchanged", "pending", "applied", "rejected"),
                )
            )
        )
    ),
    "tree": shape(dict(nodes=array(NODE), observation=OBSERVATION)),
    "find": shape(dict(ids=array(text))),
    "inspect": shape(dict(node=NODE)),
    "geometry": shape(
        dict(
            id=text,
            bounds=RECT,
            content=RECT,
            clip=RECT,
            paint_clip=RECT,
            drawable=EXTENT,
            ui_scale=number,
        )
    ),
    "diagnostics": shape(dict(diagnostics=array(DIAGNOSTIC), strict_ok=boolean)),
    "assert-no-errors": shape(dict(diagnostics=array(DIAGNOSTIC), strict_ok=boolean)),
    "snapshot": shape(
        dict(
            path=lambda v: text(v) and v.startswith("/"),
            manifest=choice("snapshot.json"),
            image=choice("screenshot.bmp"),
        )
    ),
}
for _operation in (
    "focus",
    "navigate",
    "activate",
    "cancel",
    "scroll",
    "begin-hold",
    "advance-hold",
    "release-hold",
    "cancel-hold",
):
    RESULT_SCHEMAS[_operation] = shape(ACTION_FIELDS)


def validate_reply(reply, request):
    if (
        not isinstance(reply, dict)
        or type(reply.get("protocol")) is not int
        or reply["protocol"] != 19
    ):
        raise ValueError("wrong reply protocol/schema")
    error = reply.get("error")
    if (
        type(reply.get("ok")) is not bool
        or not isinstance(error, dict)
        or set(error) != {"code", "id", "phase"}
        or not all(isinstance(error[k], str) for k in error)
        or error["phase"] not in {"request", "update", "published_frame", "snapshot"}
    ):
        raise ValueError("invalid error envelope")
    if reply["ok"] != (error["code"] == ""):
        raise ValueError("inconsistent ok/error")
    if reply.get("request_id") != request["request_id"]:
        minimum = {
            "protocol": 19,
            "request_id": request["request_id"],
            "ok": False,
            "error": {"code": "Message_Too_Large", "id": "", "phase": "request"},
        }
        encoded = (
            json.dumps(minimum, ensure_ascii=False, separators=(",", ":")).encode(
                "utf-8"
            )
            + b"\n"
        )
        if not (
            reply.get("request_id") == ""
            and error["code"] == "Message_Too_Large"
            and len(encoded) > LIMIT
        ):
            raise ValueError("reply correlation failed")
    minimal = {"protocol", "request_id", "ok", "error"}
    if set(reply) == minimal:
        if reply["ok"] or error["phase"] != "request":
            raise ValueError("invalid minimal reply")
        return
    expected = minimal | {
        "ready",
        "historical",
        "section",
        "screen_epoch",
        "frame_id",
        "model_revision",
        "published_revision",
        "result",
    }
    if set(reply) != expected:
        raise ValueError("unexpected/missing reply fields")
    for key in ("screen_epoch", "frame_id", "model_revision", "published_revision"):
        if type(reply[key]) is not int or not 0 <= reply[key] <= U64_MAX:
            raise ValueError("invalid exact u64 counter")
    if (
        type(reply["ready"]) is not bool
        or type(reply["historical"]) is not bool
        or (reply["ready"] and reply["historical"])
        or not isinstance(reply["section"], str)
        or (reply["ok"] and not isinstance(reply["result"], dict))
    ):
        raise ValueError("invalid observation/result envelope")
    # Refusals before capture/dispatch can legitimately carry null. When the
    # server supplies a result, validate it even for a failed publication or
    # Strict_Failed: the known action/diagnostic outcome must remain meaningful.
    result = reply["result"]
    if reply["ok"] or result is not None or error["code"] == "Strict_Failed":
        schema = RESULT_SCHEMAS.get(request["op"])
        if schema is None or not schema(result):
            raise ValueError("invalid operation result schema: " + request["op"])


def main(arguments=None):
    args = parser().parse_args(arguments)
    request = dict(
        protocol=19, request_id=args.request_id or uuid.uuid4().hex, op=args.op
    )
    for key in ("id", "role", "name", "section", "direction", "delta_y", "duration_ms"):
        value = getattr(args, key, None)
        if value is not None:
            request[key] = value
    encoded = (
        json.dumps(
            request, ensure_ascii=False, allow_nan=False, separators=(",", ":")
        ).encode("utf-8")
        + b"\n"
    )
    if len(encoded) > LIMIT:
        print("request including newline exceeds 1 MiB; nothing sent", file=sys.stderr)
        return 2
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
            connection.settimeout(2.0)
            connection.connect(args.socket)
            connection.sendall(encoded)
            data = bytearray()
            while b"\n" not in data:
                chunk = connection.recv(min(65536, LIMIT + 1 - len(data)))
                if not chunk:
                    raise ValueError("peer disconnected before a complete reply")
                data.extend(chunk)
                if len(data) > LIMIT:
                    raise ValueError("reply including newline exceeds 1 MiB")
            if not data.endswith(b"\n") or data.count(b"\n") != 1:
                raise ValueError("trailing reply data")
            reply = json.loads(
                data.decode("utf-8", errors="strict"),
                object_pairs_hook=object_without_duplicates,
                parse_constant=invalid_constant,
            )
            validate_reply(reply, request)
        print(
            json.dumps(
                reply, ensure_ascii=False, allow_nan=False, separators=(",", ":")
            )
        )
        return 0 if reply["ok"] else 1
    except (OSError, ValueError, UnicodeError) as error:
        print(
            f"unknown outcome: {error}; observe current state before any new intention; do not blindly resend",
            file=sys.stderr,
        )
        return 2


if __name__ == "__main__":
    sys.exit(main())
