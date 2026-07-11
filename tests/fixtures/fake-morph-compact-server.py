#!/usr/bin/env python3
"""Deterministic fake Morph /compact endpoint for llm-wiki tests.

Usage: fake-morph-compact-server.py [--port N]
Prints "PORT <n>" to stdout once listening, then serves until killed.

This does NOT emulate Morph's real compaction model -- it implements one
deterministic rule so tests can assert on exact output: keep a line only if
it is empty or contains the request's `query` string (case-insensitive);
everything else is dropped. Response shape mirrors the documented /compact
schema (output, compacted_line_ranges, kept_line_ranges, usage).
"""

from __future__ import annotations

import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer


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
        if self.path.rstrip("/") != "/compact":
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

        text = payload.get("input", "")
        query = (payload.get("query") or "").strip().lower()
        lines = text.split("\n")

        kept_ranges: list[list[int]] = []
        dropped_ranges: list[list[int]] = []
        kept_lines: list[str] = []
        for index, line in enumerate(lines):
            if not query or query in line.lower():
                kept_lines.append(line)
                kept_ranges.append([index, index])
            else:
                dropped_ranges.append([index, index])

        response = {
            "output": "\n".join(kept_lines),
            "compacted_line_ranges": dropped_ranges,
            "kept_line_ranges": kept_ranges,
            "usage": {
                "input_lines": len(lines),
                "output_lines": len(kept_lines),
            },
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
