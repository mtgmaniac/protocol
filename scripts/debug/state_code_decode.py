#!/usr/bin/env python3
"""Decode a dev state code (StateCode, scripts/autoloads/state_code.gd).

    python scripts/debug/state_code_decode.py <file holding the code> [--out <dir>]

Prints a summary (build, platform, scene, saved screen, recent errors) and, with
--out, writes payload.json, run.json and save.json there. To reproduce in
Godot, launch with the code file instead (debug builds, lands in the dev_* files):

    godot --path . -- --load-state=<file holding the code>

Format: OPSTATE1:<base64 of gzip(JSON)>:<first 8 hex of sha256(base64 text)>.
Whitespace anywhere in the code is ignored (chat apps wrap long lines).
"""
from __future__ import annotations

import base64
import gzip
import hashlib
import json
import re
import sys
from pathlib import Path

PREFIX = "OPSTATE1"
FORMAT = 1


def decode(code: str) -> dict:
    compact = re.sub(r"\s+", "", code)
    parts = compact.split(":")
    if len(parts) != 3 or parts[0] != PREFIX:
        raise ValueError(f"not a {PREFIX} state code")
    if hashlib.sha256(parts[1].encode()).hexdigest()[:8] != parts[2].lower():
        raise ValueError("checksum mismatch - the code was changed or cut short")
    payload = json.loads(gzip.decompress(base64.b64decode(parts[1])).decode("utf-8"))
    if not isinstance(payload, dict) or int(payload.get("format", 0)) != FORMAT:
        raise ValueError("not a state payload of a known format")
    return payload


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 2
    payload = decode(Path(argv[0]).read_text(encoding="utf-8"))
    run = payload.get("run_save") or {}
    print(f"build {payload.get('build_id')} ({payload.get('engine')}, debug={payload.get('debug_build')}) "
          f"on {payload.get('platform')} web={payload.get('web')} at {payload.get('created_at')}")
    print(f"scene {payload.get('scene')}  window {payload.get('window')}  visible {payload.get('visible_rect')}")
    print(f"run save: screen={run.get('screen')} seq={run.get('save_seq')} "
          f"battle={(run.get('run') or {}).get('current_battle')} "
          f"checkpoint={'yes' if run.get('battle_checkpoint') else 'no'}  sources {payload.get('run_save_sources')}")
    print(f"live: {json.dumps(payload.get('live'))[:400]}")
    errors = payload.get("errors") or []
    print(f"{len(errors)} recent errors/warnings:")
    for entry in errors[-20:]:
        print(f"  [{entry.get('t')}ms {entry.get('kind')}] {entry.get('text')}  ({entry.get('where')})")
    if "--out" in argv:
        out = Path(argv[argv.index("--out") + 1])
        out.mkdir(parents=True, exist_ok=True)
        (out / "payload.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")
        (out / "run.json").write_text(json.dumps(run, indent=2), encoding="utf-8")
        (out / "save.json").write_text(json.dumps(payload.get("profile") or {}, indent=2), encoding="utf-8")
        print(f"wrote payload.json, run.json, save.json to {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
