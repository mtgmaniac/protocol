"""Exercise Godot HTTPRequest against loopback only; never send production data."""
import json
import os
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get("GODOT_BIN", "C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe")
received = []


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def do_POST(self):
        event = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        received.append(event["event_name"])
        name = event["event_name"]
        first = received.count(name) == 1
        if name == "timeout" and first:
            time.sleep(3)
        body = b"not json" if name == "bad_json" and first else b'{"ok":true}'
        self.send_response(500 if name == "server_error" and first else 200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            pass


def main():
    with ThreadingHTTPServer(("127.0.0.1", 0), Handler) as server:
        threading.Thread(target=server.serve_forever, daemon=True).start()
        try:
            result = subprocess.run(
                [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/telemetry_test.gd", "--",
                 f"http://127.0.0.1:{server.server_port}/telemetry"],
                capture_output=True, text=True, timeout=60, cwd=ROOT)
        finally:
            server.shutdown()
    output = result.stdout + result.stderr
    print(output)
    expected = ["server_error", "server_error", "bad_json", "bad_json", "timeout", "timeout"]
    received[:] = [name for name in received if name != "cancelled"]
    if result.returncode or "[TELEMETRY] PASS" not in output or received != expected or "ERROR:" in output:
        print(f"[TELEMETRY_GATE] FAIL: requests {received!r}; failure/reload retries expected")
        return 1
    print("[TELEMETRY_GATE] PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
