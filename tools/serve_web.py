#!/usr/bin/env python3
"""Serve build/web/ over HTTPS on the LAN for testing the Godot web export on a phone.

Usage:  python tools/serve_web.py [port]        (default port 8060)
Open:   https://<this-machine's-LAN-IP>:<port>/  from the phone (same wifi).

HTTPS matters: Godot's web shell requires a Secure Context, and while
`localhost` qualifies over plain http, a LAN IP does not — phone testing needs
TLS. A self-signed certificate is generated on first run (openssl CLI, or the
`cryptography` module if installed) and cached next to this script
(serve_web_cert.pem / serve_web_key.pem — gitignored). Phones show a ONE-TIME
certificate warning to click through (Android Chrome: Advanced → "Proceed
anyway"; iOS Safari: "Show Details" → "visit this website"). If cert
generation fails the server falls back to plain http with a printed warning
(desktop-browser testing still works there).

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
import shutil
import socket
import ssl
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT = SCRIPT_DIR.parent / "build" / "web"
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8060
CERT = SCRIPT_DIR / "serve_web_cert.pem"
KEY = SCRIPT_DIR / "serve_web_key.pem"


# allow_reuse_address (the HTTPServer default) lets a second instance silently
# double-bind the port on Windows — the stale instance then wins accepts and
# an https launch appears to serve plain http. Fail loudly instead.
class Server(http.server.ThreadingHTTPServer):
    allow_reuse_address = False


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


def _find_openssl() -> str | None:
    exe = shutil.which("openssl")
    if exe:
        return exe
    for candidate in (
        r"C:\Program Files\Git\mingw64\bin\openssl.exe",
        r"C:\Program Files\Git\usr\bin\openssl.exe",
    ):
        if Path(candidate).exists():
            return candidate
    return None


def _generate_cert_openssl(ip: str) -> bool:
    exe = _find_openssl()
    if exe is None:
        return False
    result = subprocess.run(
        [
            exe, "req", "-x509", "-newkey", "rsa:2048", "-sha256", "-nodes",
            "-days", "825",
            "-keyout", str(KEY), "-out", str(CERT),
            "-subj", "/CN=overload-protocol-lan",
            "-addext", f"subjectAltName=DNS:localhost,IP:127.0.0.1,IP:{ip}",
        ],
        capture_output=True,
    )
    return result.returncode == 0 and CERT.exists() and KEY.exists()


def _generate_cert_cryptography(ip: str) -> bool:
    try:
        import datetime
        import ipaddress
        from cryptography import x509
        from cryptography.hazmat.primitives import hashes, serialization
        from cryptography.hazmat.primitives.asymmetric import rsa
        from cryptography.x509.oid import NameOID
    except ImportError:
        return False
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "overload-protocol-lan")])
    now = datetime.datetime.now(datetime.timezone.utc)
    cert = (
        x509.CertificateBuilder()
        .subject_name(name).issuer_name(name).public_key(key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now).not_valid_after(now + datetime.timedelta(days=825))
        .add_extension(x509.SubjectAlternativeName([
            x509.DNSName("localhost"),
            x509.IPAddress(ipaddress.ip_address("127.0.0.1")),
            x509.IPAddress(ipaddress.ip_address(ip)),
        ]), critical=False)
        .sign(key, hashes.SHA256())
    )
    KEY.write_bytes(key.private_bytes(
        serialization.Encoding.PEM, serialization.PrivateFormat.TraditionalOpenSSL,
        serialization.NoEncryption()))
    CERT.write_bytes(cert.public_bytes(serialization.Encoding.PEM))
    return True


def ensure_cert(ip: str) -> bool:
    """True if a usable cert/key pair exists (cached or freshly generated)."""
    if CERT.exists() and KEY.exists():
        return True
    return _generate_cert_openssl(ip) or _generate_cert_cryptography(ip)


def main() -> None:
    if not (ROOT / "index.html").exists():
        sys.exit(f"No build found at {ROOT} — export the Web preset first.")
    ip = lan_ip()
    try:
        server = Server(("0.0.0.0", PORT), Handler)
    except OSError as e:
        sys.exit(f"Port {PORT} is already in use ({e}) — stop the other server first.")
    scheme = "http"
    if ensure_cert(ip):
        try:
            ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            ctx.load_cert_chain(str(CERT), str(KEY))
            server.socket = ctx.wrap_socket(server.socket, server_side=True)
            scheme = "https"
        except (ssl.SSLError, OSError) as e:
            print(f"WARNING: TLS setup failed ({e}) — serving plain http.", flush=True)
            print("         Phones will hit Godot's Secure Context error; localhost still works.", flush=True)
    else:
        print("WARNING: could not generate a self-signed cert (no openssl, no cryptography module).", flush=True)
        print("         Serving plain http — phones will hit Godot's Secure Context error.", flush=True)
    print(f"Serving {ROOT}", flush=True)
    print(f"  local:  {scheme}://localhost:{PORT}/", flush=True)
    print(f"  phone:  {scheme}://{ip}:{PORT}/   (same wifi; allow python through"
          " the Windows firewall if it doesn't load)", flush=True)
    if scheme == "https":
        print("  Phones show a ONE-TIME certificate warning: Android Chrome ->", flush=True)
        print("  Advanced -> 'Proceed anyway'; iOS Safari -> Show Details -> 'visit this website'.", flush=True)
    print("Ctrl+C to stop.", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
