#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
COMPACT="$ROOT/scripts/morph-compact"
FAKE_SERVER="$ROOT/tests/fixtures/fake-morph-compact-server.py"

mkdir -p "$ROOT/.tmp"
TMP_ROOT="$(mktemp -d "$ROOT/.tmp/morph-compact-test.XXXXXX")"
SERVER_PID=""

cleanup() {
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

echo "=== morph-compact tests ==="

INPUT_FILE="$TMP_ROOT/input.txt"
printf '%s\n%s\n%s\n%s' \
  "line one is filler" \
  "line two mentions JWT validation directly" \
  "line three is also filler" \
  "line four discusses JWT refresh tokens" \
  > "$INPUT_FILE"

unset MORPH_API_KEY MORPH_API_BASE_URL || true

# (a) no key configured -> verbatim passthrough, exit 0
OUTPUT="$("$COMPACT" --input "$INPUT_FILE" --query "JWT")"
if [[ "$OUTPUT" != "$(cat "$INPUT_FILE")" ]]; then
  echo "FAIL: no-key run should pass input through verbatim" >&2
  exit 1
fi
echo "  PASS: no MORPH_API_KEY -> verbatim passthrough"

# (b) --dry-run with no key -> reports would_call=false, no network attempted
"$COMPACT" --input "$INPUT_FILE" --query "JWT" --dry-run | python3 -c '
import json, sys
data = json.load(sys.stdin)
assert data["would_call"] is False
assert data["fallback"] == "verbatim passthrough"
'
echo "  PASS: --dry-run with no key reports would_call=false"

# --dry-run WITH a key -> previews the request, still no network call
MORPH_API_KEY=test-key-123456 "$COMPACT" --input "$INPUT_FILE" --query "JWT" --dry-run | python3 -c '
import json, sys
data = json.load(sys.stdin)
assert data["would_call"] is True
assert data["url"].endswith("/compact")
assert data["headers"]["Authorization"].startswith("Bearer test")
assert "input" in data["payload"] and "chars" in data["payload"]["input"]
'
echo "  PASS: --dry-run with key previews the request without calling the network"

# (c) happy path against the fake compact server
SERVER_OUT="$(mktemp "$TMP_ROOT/server-out.XXXXXX")"
python3 "$FAKE_SERVER" --port 0 > "$SERVER_OUT" 2>&1 &
SERVER_PID=$!
for _ in $(seq 1 50); do
  [[ -s "$SERVER_OUT" ]] && break
  sleep 0.1
done
PORT="$(awk '{print $2}' "$SERVER_OUT" | head -n1)"
if [[ -z "${PORT:-}" ]]; then
  echo "FAIL: fake compact server did not report a port" >&2
  cat "$SERVER_OUT" >&2
  exit 1
fi

MORPH_API_KEY="test-key-123456" MORPH_API_BASE_URL="http://127.0.0.1:$PORT" \
  "$COMPACT" --input "$INPUT_FILE" --query "JWT" --json | python3 -c '
import json, sys
data = json.load(sys.stdin)
assert "JWT" in data["output"]
assert "filler" not in data["output"]
assert len(data["compacted_line_ranges"]) == 2
assert len(data["kept_line_ranges"]) == 2
assert data["usage"]["output_lines"] == 2
'
echo "  PASS: happy path drops filler lines and keeps query-relevant lines"

kill "$SERVER_PID" 2>/dev/null || true
wait "$SERVER_PID" 2>/dev/null || true
SERVER_PID=""

# (d) unreachable endpoint (server just killed, port freshly freed) -> graceful fallback
MORPH_API_KEY="test-key-123456" MORPH_API_BASE_URL="http://127.0.0.1:$PORT" \
  "$COMPACT" --input "$INPUT_FILE" --query "JWT" > "$TMP_ROOT/stdout.txt" 2> "$TMP_ROOT/stderr.txt"
if [[ "$(cat "$TMP_ROOT/stdout.txt")" != "$(cat "$INPUT_FILE")" ]]; then
  echo "FAIL: unreachable server should fall back to verbatim passthrough" >&2
  exit 1
fi
if ! grep -q "falling back to verbatim passthrough" "$TMP_ROOT/stderr.txt"; then
  echo "FAIL: expected a stderr warning on fallback" >&2
  exit 1
fi
echo "  PASS: unreachable Morph endpoint falls back to verbatim passthrough"

# (e) retry policy: transient statuses retried with backoff; 4xx fails fast;
#     total attempts stay bounded. Uses a counting server + retry_backoff=0 so
#     the test is deterministic and adds no real delay.
python3 - "$ROOT/scripts" <<'PY'
import sys, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

sys.path.insert(0, sys.argv[1])
import _morph_client as morph


def make_server(statuses):
    state = {"i": 0, "count": 0}

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):  # keep test output quiet
            pass

        def do_POST(self):
            length = int(self.headers.get("Content-Length", 0))
            if length:
                self.rfile.read(length)
            state["count"] += 1
            idx = state["i"]
            state["i"] += 1
            code = statuses[idx] if idx < len(statuses) else statuses[-1]
            body = b'{"output": "ok"}' if code == 200 else b'{"detail": "err"}'
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    srv = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv, state


def call(srv, **kw):
    base = f"http://127.0.0.1:{srv.server_address[1]}"
    return morph.post_json("/compact", {"input": "x"}, "k", base, timeout=5, retry_backoff=0, **kw)


# 503, 503, 200 with retries=2 -> succeeds on the 3rd attempt
srv, st = make_server([503, 503, 200])
ok, data = call(srv, retries=2)
srv.shutdown()
assert ok is True, f"transient-then-success expected ok, got {data!r}"
assert st["count"] == 3, f"expected 3 attempts, got {st['count']}"

# 400 with retries=2 -> fails fast, exactly 1 attempt (4xx is not retried)
srv, st = make_server([400])
ok, data = call(srv, retries=2)
srv.shutdown()
assert ok is False, "4xx expected failure"
assert st["count"] == 1, f"4xx must not retry; expected 1 attempt, got {st['count']}"

# persistent 503 with retries=1 -> 2 attempts then fail (bounded)
srv, st = make_server([503])
ok, data = call(srv, retries=1)
srv.shutdown()
assert ok is False, "persistent 503 expected failure"
assert st["count"] == 2, f"retries=1 -> 2 attempts, got {st['count']}"

print("  PASS: retry policy - transient retried, 4xx fails fast, attempts bounded")
PY

echo "All morph-compact tests passed."
