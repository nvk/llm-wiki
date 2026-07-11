#!/usr/bin/env python3
"""Deterministic fake Morph WarpGrep endpoint for llm-wiki tests.

Usage: fake-morph-warpgrep-server.py [--port N]
Prints "PORT <n>" to stdout once listening, then serves until killed.

This validates scripts/warp-grep's request/response handling, not Morph's
real (undocumented in what we fetched) WarpGrep contract -- it always
returns the same two fixed matches regardless of searchTerm/repoRoot.
"""

from __future__ import annotations

import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

FIXED_MATCHES = [
    {"file": "src/example.py", "line": 1, "snippet": "def handle_request(term):"},
    {"file": "src/example.py", "line": 3, "snippet": "    return search(term)"},
]


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):  # noqa: A002 - stdlib signature
        pass

    def _json_error(self, code: int, message: str) -> None:
        body = json.dumps({"error": message}).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self) -> None:  # noqa: N802 - stdlib method name
        if self.path.rstrip("/") != "/warp-grep":
            self._json_error(404, "not found")
            return

        auth = self.headers.get("Authorization", "")
        if not auth.startswith("Bearer ") or not auth[len("Bearer "):]:
            self._json_error(401, "missing bearer token")
            return

        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length)
        try:
            payload = json.loads(raw.decode("utf-8"))
        except json.JSONDecodeError:
            self._json_error(400, "invalid json")
            return

        response = {
            "searchTerm": payload.get("searchTerm", ""),
            "repoRoot": payload.get("repoRoot", ""),
            "matches": FIXED_MATCHES,
        }
        body = json.dumps(response).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main() -> int:
    port = 0
    if "--port" in sys.argv:
        port = int(sys.argv[sys.argv.index("--port") + 1])
    server = HTTPServer(("127.0.0.1", port), Handler)
    print(f"PORT {server.server_address[1]}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
