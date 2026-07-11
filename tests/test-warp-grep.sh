#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
WARPGREP="$ROOT/scripts/warp-grep"
FAKE_SERVER="$ROOT/tests/fixtures/fake-morph-warpgrep-server.py"

mkdir -p "$ROOT/.tmp"
TMP_ROOT="$(mktemp -d "$ROOT/.tmp/warp-grep-test.XXXXXX")"
SERVER_PID=""

cleanup() {
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

echo "=== warp-grep tests ==="

REPO_ROOT="$TMP_ROOT/fixture-repo"
mkdir -p "$REPO_ROOT/src"
cat > "$REPO_ROOT/src/example.py" <<'PY'
def handle_request(term):
    print("looking up", term)
    return search(term)


def search(term):
    return []
PY

unset MORPH_API_KEY MORPH_API_BASE_URL || true

# (a) no key -> local fallback search finds a real match, no network attempted
"$WARPGREP" "handle_request" --repo-root "$REPO_ROOT" --json --compact-json | python3 -c '
import json, sys
data = json.load(sys.stdin)
assert "local-fallback" in data["source"], data
assert any("handle_request" in m["snippet"] for m in data["matches"]), data
'
echo "  PASS: no MORPH_API_KEY -> local fallback search finds real matches"

# (b) --dry-run with no key -> reports would_call=false, no search or network performed
"$WARPGREP" "handle_request" --repo-root "$REPO_ROOT" --dry-run | python3 -c '
import json, sys
data = json.load(sys.stdin)
assert data["would_call"] is False
assert data["fallback"] == "local search"
'
echo "  PASS: --dry-run with no key reports would_call=false"

# --dry-run WITH a key -> previews the request, still no network call
MORPH_API_KEY=test-key-123456 "$WARPGREP" "handle_request" --repo-root "$REPO_ROOT" --dry-run | python3 -c '
import json, sys
data = json.load(sys.stdin)
assert data["would_call"] is True
assert data["url"].endswith("/warp-grep")
assert data["headers"]["Authorization"].startswith("Bearer test")
assert data["payload"]["searchTerm"] == "handle_request"
'
echo "  PASS: --dry-run with key previews the request without calling the network"

# (c) happy path against the fake warp-grep server
SERVER_OUT="$(mktemp "$TMP_ROOT/server-out.XXXXXX")"
python3 "$FAKE_SERVER" --port 0 > "$SERVER_OUT" 2>&1 &
SERVER_PID=$!
for _ in $(seq 1 50); do
  [[ -s "$SERVER_OUT" ]] && break
  sleep 0.1
done
PORT="$(awk '{print $2}' "$SERVER_OUT" | head -n1)"
if [[ -z "${PORT:-}" ]]; then
  echo "FAIL: fake warp-grep server did not report a port" >&2
  cat "$SERVER_OUT" >&2
  exit 1
fi

MORPH_API_KEY="test-key-123456" MORPH_API_BASE_URL="http://127.0.0.1:$PORT" \
  "$WARPGREP" "handle_request" --repo-root "$REPO_ROOT" --json --compact-json | python3 -c '
import json, sys
data = json.load(sys.stdin)
assert data["source"] == "morph-warpgrep", data
assert len(data["matches"]) == 2
assert data["matches"][0]["file"] == "src/example.py"
'
echo "  PASS: happy path returns matches from the fake Morph endpoint"

kill "$SERVER_PID" 2>/dev/null || true
wait "$SERVER_PID" 2>/dev/null || true
SERVER_PID=""

# (d) unreachable endpoint (server just killed, port freshly freed) -> local fallback
MORPH_API_KEY="test-key-123456" MORPH_API_BASE_URL="http://127.0.0.1:$PORT" \
  "$WARPGREP" "handle_request" --repo-root "$REPO_ROOT" --json --compact-json \
  > "$TMP_ROOT/stdout.txt" 2> "$TMP_ROOT/stderr.txt"
python3 -c '
import json
data = json.load(open("'"$TMP_ROOT"'/stdout.txt"))
assert "local-fallback" in data["source"], data
assert any("handle_request" in m["snippet"] for m in data["matches"]), data
'
if ! grep -q "falling back to local search" "$TMP_ROOT/stderr.txt"; then
  echo "FAIL: expected a stderr warning on fallback" >&2
  exit 1
fi
echo "  PASS: unreachable Morph endpoint falls back to local search"

echo "All warp-grep tests passed."
