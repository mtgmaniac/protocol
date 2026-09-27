#!/usr/bin/env python3
"""List the files packed in a Godot 4 .pck (formats 2 and 3, unencrypted directory).

Used to prove dev-only trees (dev/, the framing editor) are absent from an
export — the UID cache inside a pack still NAMES excluded paths, so a raw
string search is not evidence; the pack directory is.

    python scripts/checks/pck_list.py build.pck [--grep dev/]
"""
from __future__ import annotations

import struct
import sys


def pck_files(path: str) -> list[str]:
    with open(path, "rb") as f:
        data = f.read()
    start = data.find(b"GDPC")
    if start < 0:
        raise SystemExit(f"{path}: no GDPC header")
    pos = start + 4
    version, _maj, _min, _pat = struct.unpack_from("<4I", data, pos)
    pos += 16
    if version not in (2, 3):
        raise SystemExit(f"{path}: unsupported pck format {version}")
    flags, _file_base = struct.unpack_from("<IQ", data, pos)
    pos += 12
    if flags & 1:
        raise SystemExit(f"{path}: encrypted directory")
    if version == 3:
        (dir_offset,) = struct.unpack_from("<Q", data, pos)
        pos = start + dir_offset
    else:
        pos += 16 * 4  # reserved
    (count,) = struct.unpack_from("<I", data, pos)
    pos += 4
    out = []
    for _ in range(count):
        (length,) = struct.unpack_from("<I", data, pos)
        pos += 4
        out.append(data[pos:pos + length].rstrip(b"\0").decode("utf-8"))
        pos += length + 8 + 8 + 16 + 4  # offset, size, md5, flags
    return out


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    files = pck_files(sys.argv[1])
    needle = sys.argv[sys.argv.index("--grep") + 1] if "--grep" in sys.argv else None
    shown = [f for f in files if needle is None or needle in f]
    for f in shown:
        print(f)
    print(f"[PCK_LIST] {len(files)} files" + (f", {len(shown)} matching '{needle}'" if needle else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
