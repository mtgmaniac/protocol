#!/usr/bin/env python3
"""Serve build/web/ on the LAN for testing the Godot web export on a phone.

Usage:  python tools/serve_web.py [port]        (default port 8060)
Open:   http://<this-machine's-LAN-IP>:<port>/  from the phone (same wifi).

Notes for a NON-THREADED Godot 4 web build:
- No COOP/COEP (cross-origin isolation) headers are required — that is the whole
  point of exporting with thread support disabled (iOS Safari compatibility).
- What IS required: correct MIME for .wasm (application/wasm), otherwise the
  browser refuses WebAssembly.instantiateStreaming.
- ThreadingHTTPServer matters: Safari fetches wasm + pck in parallel and a
  serial server stalls the load.
- Cache-Control: no-store so re-exports show up without fighting Safari's cache.
"""
import http.server
import socket
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "build" / "web"
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8060


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".js": "text/javascript",
        ".pck": "application/octet-stream",
    }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def lan_ip() -> str:
    """Best-effort LAN IP (no traffic is actually sent)."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"


def main() -> None:
    if not (ROOT / "index.html").exists():
        sys.exit(f"No build found at {ROOT} — export the Web preset first.")
    server = http.server.ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"Serving {ROOT}", flush=True)
    print(f"  local:  http://localhost:{PORT}/", flush=True)
    print(f"  phone:  http://{lan_ip()}:{PORT}/   (same wifi; allow python through"
          " the Windows firewall if it doesn't load)", flush=True)
    print("Ctrl+C to stop.", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
