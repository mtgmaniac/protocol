"""Prove the recorded-throw gate catches wrong tops and in-flight relabels."""
from pathlib import Path
import os
import subprocess

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get("GODOT_BIN", "C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe")
out = ROOT / "debug_artifacts"
for kind, needle in [("top", "scripted top face differs"), ("labels", "labels changed during recorded playback")]:
    result = subprocess.run([GODOT, "--headless", "--path", str(ROOT), "--script",
                             "scripts/debug/tutorial_throw_gate.gd", "--", f"--break={kind}"],
                            capture_output=True, text=True, timeout=90)
    log = result.stdout + result.stderr
    (out / f"tutorial_throw_mutation_{kind}.log").write_text(log, encoding="utf-8")
    if result.returncode != 1 or needle not in log or "SCRIPT ERROR" in log:
        raise SystemExit(f"[TUTORIAL_MUTATIONS] FAIL: {kind}\n{log[-2500:]}")
    print(f"[TUTORIAL_MUTATIONS] detected {kind}", flush=True)
print("[TUTORIAL_MUTATIONS] PASS: 2/2 deliberately broken checks detected")
