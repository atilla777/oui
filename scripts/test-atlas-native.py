#!/usr/bin/env python3
"""Bounded local libpng ABI/fault target; never installs or downloads dependencies."""

import argparse
import hashlib
import pathlib
import re
import shutil
import subprocess
import tempfile
import tarfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
NATIVE = ROOT / "consumer/atlas_catalog/native"
PIN = "cd952f49f95bb27154ae77dbb103032d95f6e580"
HEADER = "5758258cb691e429bafbf16057210e2d9bfa2c33b6c4636a6db562480f39b273"
ARCHIVE_SHA = "d80dd2a38a37f803cb9b6ac7b14bd6e74ddc3b654780a8380bdf93523fdb4389"


def run(args, **kwargs):
    print("+", " ".join(map(str, args)), flush=True)
    subprocess.run(list(map(str, args)), check=True, cwd=ROOT, **kwargs)


def check_linkage(binary, shared_png):
    """Check actual Linux loader resolution, including libpng's transitive zlib."""
    text = subprocess.check_output(["ldd", str(binary)], text=True)
    print(text, flush=True)
    loaded = dict(re.findall(r"\s+(lib(?:z|png16)\.so[^ ]*) => (\S+)", text))
    expected = {"libz.so": "zlib"}
    if shared_png:
        expected["libpng16.so"] = "libpng"
    elif any(name.startswith("libpng16.so") for name in loaded):
        raise SystemExit("fault target must not also load shared libpng")
    for name, package in expected.items():
        paths = [path for key, path in loaded.items() if key.startswith(name)]
        directory = pathlib.Path(
            subprocess.check_output(
                ["pkg-config", "--variable=libdir", package], text=True
            ).strip()
        ).resolve(strict=True)
        if (
            len(paths) != 1
            or pathlib.Path(paths[0]).resolve(strict=True).parent != directory
        ):
            raise SystemExit(
                f"mixed/missing {package} resolution: {paths}; expected {directory}"
            )


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument(
        "--source",
        type=pathlib.Path,
        required=True,
        help=f"local official libpng source at {PIN}",
    )
    p.add_argument(
        "--archive",
        type=pathlib.Path,
        help="official libpng-1.6.59.tar.xz, required for an extracted source tree",
    )
    args = p.parse_args()
    source = args.source.resolve(strict=True)
    # Require the pinned tree, not only a same-version header.
    archive_tree = False
    if (source / ".git").exists():
        archive_tree = (
            subprocess.check_output(
                ["git", "-C", str(source), "rev-parse", "HEAD"], text=True
            ).strip()
            == PIN
        )
        if subprocess.check_output(["git", "-C", str(source), "status", "--porcelain"]):
            raise SystemExit("source tree is dirty")
    elif args.archive is not None:
        archive = args.archive.resolve(strict=True)
        if hashlib.sha256(archive.read_bytes()).hexdigest() != ARCHIVE_SHA:
            raise SystemExit("pinned source archive digest mismatch")
        with tarfile.open(archive) as tar:
            expected = {}
            for member in tar.getmembers():
                relative = pathlib.PurePosixPath(member.name).relative_to(
                    "libpng-1.6.59"
                )
                if member.isfile() and relative.suffix in (".c", ".h"):
                    expected[str(relative)] = tar.extractfile(member).read()
            actual = {
                str(path.relative_to(source)): path.read_bytes()
                for path in source.rglob("*")
                if path.is_file() and path.suffix in (".c", ".h")
            }
            archive_tree = expected == actual
    if (
        not archive_tree
        or hashlib.sha256((source / "png.h").read_bytes()).hexdigest() != HEADER
    ):
        raise SystemExit("pinned source identity/header mismatch")
    prefix = pathlib.Path(
        subprocess.check_output(
            ["pkg-config", "--variable=includedir", "libpng"], text=True
        ).strip()
    )
    config = prefix / "pnglibconf.h"
    flags = subprocess.check_output(
        ["pkg-config", "--cflags", "--libs", "libpng", "zlib"], text=True
    ).split()
    cflags = subprocess.check_output(
        ["pkg-config", "--cflags", "libpng", "zlib"], text=True
    ).split()
    zflags = subprocess.check_output(
        ["pkg-config", "--cflags", "--libs", "zlib"], text=True
    ).split()
    work = pathlib.Path(tempfile.mkdtemp(prefix="frx9-native-", dir="/tmp/opencode"))
    print(f"retained native evidence/build: {work}", flush=True)
    shutil.copyfile(config, work / "pnglibconf.h")
    run(["cc", NATIVE / "abi.c", *flags, "-o", work / "abi-production"])
    run([work / "abi-production"])
    check_linkage(work / "abi-production", shared_png=True)
    print(
        "config sha256=" + hashlib.sha256(config.read_bytes()).hexdigest(), flush=True
    )
    objects = []
    for name in (
        "png pngerror pngget pngmem pngpread pngread pngrio pngrtran pngrutil "
        "pngset pngtrans pngwio pngwrite pngwtran pngwutil"
    ).split():
        obj = work / f"{name}.o"
        extra = (
            [
                "-Dmalloc=atlas_test_malloc",
                "-Dfree=atlas_test_free",
                "-include",
                NATIVE / "fault.h",
            ]
            if name == "pngmem"
            else []
        )
        run(
            [
                "cc",
                "-O1",
                "-g",
                "-fPIC",
                f"-I{work}",
                f"-I{source}",
                *cflags,
                *extra,
                "-c",
                source / f"{name}.c",
                "-o",
                obj,
            ]
        )
        objects.append(obj)
    run(["cc", "-O1", "-g", "-fPIC", "-c", NATIVE / "fault.c", "-o", work / "fault.o"])
    library = work / "libatlas_png_fault.a"
    run(["ar", "rcs", library, *objects, work / "fault.o"])
    run(
        [
            "cc",
            f"-I{work}",
            f"-I{source}",
            NATIVE / "abi.c",
            library,
            *zflags,
            "-lm",
            "-o",
            work / "abi-fault",
        ]
    )
    run([work / "abi-fault"])
    check_linkage(work / "abi-fault", shared_png=False)
    common = [
        "odin",
        "test",
        "consumer/atlas_catalog/loader",
        "-collection:ui=kit",
        "-define:ODIN_TEST_THREADS=1",
        "-keep-executable",
    ]
    run(
        [
            *common,
            f"-extra-linker-flags:{' '.join(flags)}",
            f"-out:{work}/production-tests",
        ]
    )
    check_linkage(work / "production-tests", shared_png=True)
    run(
        [
            *common,
            "-define:ATLAS_NATIVE_FAULT_TEST=true",
            "-define:ATLAS_PNG_LIBRARY=system:c",
            f"-extra-linker-flags:{library} {' '.join(zflags)} -lm",
            f"-out:{work}/fault-tests",
        ]
    )
    check_linkage(work / "fault-tests", shared_png=False)


if __name__ == "__main__":
    main()
