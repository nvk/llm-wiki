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

echo "All morph-compact tests passed."
