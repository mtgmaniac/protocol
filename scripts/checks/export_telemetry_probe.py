"""Explicit local-web probe export. Does not send until opened in localhost."""
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
project = ROOT / "project.godot"
scene = ROOT / "scenes/ui/TelemetryWebSmoke.tscn"
out = ROOT / "build/telemetry-web"
original = project.read_bytes()
assert not scene.exists(), "Temporary scene already exists; inspect before replacing"
try:
    out.mkdir(parents=True, exist_ok=True)
    scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/debug/telemetry_live_smoke.gd" id="1"]\n[node name="TelemetryProbe" type="Node"]\nscript = ExtResource("1")\n')
    lines = original.decode("utf-8").splitlines(keepends=True)
    project.write_text("".join('run/main_scene="res://scenes/ui/TelemetryWebSmoke.tscn"\n' if line.startswith('run/main_scene=') else line for line in lines), encoding="utf-8")
    subprocess.run([os.environ["GODOT_BIN"], "--headless", "--path", str(ROOT), "--export-release", "Web", str(out / "index.html")], check=True)
    html = out / "index.html"
    html.write_text(html.read_text(encoding="utf-8").replace("engine.startGame({", "engine.startGame({args: ['--', '--send-telemetry-smoke'],", 1), encoding="utf-8")
finally:
    project.write_bytes(original)
    scene.unlink(missing_ok=True)
