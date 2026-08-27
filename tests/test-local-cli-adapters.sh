#!/usr/bin/env bash
# Validate the deterministic local private-adapter registry and v1 execution boundary.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CLI="$PROJECT_ROOT/scripts/llm-wiki"
PASS=0
FAIL=0
TOTAL=0

log_pass() { PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[32mPASS\033[0m: %s\n" "$1"; }
log_fail() { FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[31mFAIL\033[0m: %s - %s\n" "$1" "$2"; }

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
export LLM_WIKI_CONFIG_DIR="$tmpdir/config"
adapter="$tmpdir/private-adapter"
inputs="$tmpdir/inputs"
outputs="$tmpdir/outputs"
outside="$tmpdir/outside"
mkdir -p "$adapter" "$inputs" "$outputs" "$outside"
printf 'fixture input\n' > "$inputs/case.json"
printf '{"requests":[{"insertText":{"text":"synthetic","location":{"index":1}}}]}\n' > "$inputs/plan.json"

cat > "$adapter/.llm-wiki-adapter.json" <<'JSON'
{
  "protocol": "llm-wiki-adapter/v1",
  "id": "fixture-private",
  "version": "1.0.0",
  "distribution": "private",
  "entrypoint": ["./bin/adapter"],
  "capabilities": ["fixture-analysis"],
  "routes": [
    {
      "id": "edit-fixture-document",
      "intents": ["edit", "revise"],
      "resource": {
        "kind": "url",
        "schemes": ["https"],
        "hosts": ["editor.fixture.invalid"],
        "path_prefixes": ["/document/"]
      },
      "guide": "AGENT_WORKFLOW.md",
      "priority": 50
    }
  ],
  "network": "none",
  "writes_wiki": false,
  "operations": {
    "analyze": {
      "read_arguments": ["case"],
      "requires_output_dir": true
    },
    "suggest": {
      "read_arguments": ["plan"],
      "remote_resource_arguments": ["document_resource"],
      "requires_output_dir": true,
      "approved_plan_argument": "plan",
      "effects": ["remote-read", "remote-write"]
    }
  },
  "output_classes": ["wiki-safe", "private"]
}
JSON

cat > "$adapter/AGENT_WORKFLOW.md" <<'MARKDOWN'
# Fixture adapter workflow

Follow this registered adapter's private workflow.
MARKDOWN

cat > "$adapter/adapter.py" <<'PY'
#!/usr/bin/env python3
import argparse, hashlib, json, os
from pathlib import Path

root = Path(os.environ["LLM_WIKI_ADAPTER_ROOT"])
parser = argparse.ArgumentParser()
sub = parser.add_subparsers(dest="command", required=True)
sub.add_parser("describe")
execute = sub.add_parser("execute")
execute.add_argument("--request", required=True)
execute.add_argument("--response", required=True)
args = parser.parse_args()
if args.command == "describe":
    print((root / ".llm-wiki-adapter.json").read_text())
    raise SystemExit(0)
request = json.loads(Path(args.request).read_text())
output = Path(request["output_dir"])
output.mkdir(parents=True, exist_ok=True)
if request["operation"] == "suggest":
    (output / "executed").write_text("synthetic remote write\n")
    remote_write = request["remote_write"]
    response = {
        "protocol": "llm-wiki-adapter/v1",
        "adapter_id": "fixture-private",
        "adapter_version": "1.0.0",
        "operation": "suggest",
        "status": "ok",
        "run_id": "fixture-remote-run",
        "summary": {"synthetic_content": "DO NOT PRINT THIS REMOTE CONTENT"},
        "artifacts": [],
        "remote_receipt": {
            "status": "verified",
            "resources": [request["arguments"]["document_resource"]],
            "plan_sha256": remote_write["plan_sha256"],
            "idempotency_key": remote_write["idempotency_key"],
            "before_revision": remote_write["expected_revision"],
            "after_revision": "revision-2",
            "verification": {"status": "verified", "suggestion_count": 1}
        }
    }
    Path(args.response).write_text(json.dumps(response))
    raise SystemExit(0)
artifact = output / "packet.json"
artifact.write_text(json.dumps({"case": Path(request["arguments"]["case"]).name}) + "\n")
response = {
    "protocol": "llm-wiki-adapter/v1",
    "adapter_id": "fixture-private",
    "adapter_version": "1.0.0",
    "operation": request["operation"],
    "status": "ok",
    "run_id": "fixture-run",
    "summary": {"records": 1},
    "artifacts": [{
        "path": "packet.json",
        "sha256": hashlib.sha256(artifact.read_bytes()).hexdigest(),
        "class": "wiki-safe",
        "media_type": "application/json",
        "role": "evidence-packet"
    }]
}
Path(args.response).write_text(json.dumps(response))
PY
chmod +x "$adapter/adapter.py"
mkdir "$adapter/bin"
ln -s ../adapter.py "$adapter/bin/adapter"

echo "=== Local llm-wiki CLI Adapters ==="

set +e
add_output="$("$CLI" adapter add "$adapter" --read-root "$inputs" --write-root "$outputs" \
  --remote-resource 'fixture-document:synthetic' --json 2>&1)"
add_rc=$?
set -e
registry="$LLM_WIKI_CONFIG_DIR/adapters.json"
if [ "$add_rc" -eq 0 ] \
  && [ -f "$registry" ] \
  && python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["status"] == "registered"; assert d["id"] == "fixture-private"' <<<"$add_output" \
  && [ "$(python3 -c 'import os,sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$registry")" = "0o600" ]; then
  log_pass "add writes a private machine-local registration with explicit path scopes"
else
  log_fail "add writes a private machine-local registration with explicit path scopes" "$add_output"
fi

set +e
doctor_output="$("$CLI" adapter doctor fixture-private --json 2>&1)"
doctor_rc=$?
set -e
if [ "$doctor_rc" -eq 0 ] \
  && python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["status"] == "healthy"; assert d["handshake"]["id"] == "fixture-private"' <<<"$doctor_output"; then
  log_pass "doctor validates the manifest hash, executable, and describe handshake"
else
  log_fail "doctor validates the manifest hash, executable, and describe handshake" "$doctor_output"
fi

list_output="$("$CLI" adapter list --json)"
show_output="$("$CLI" adapter show fixture-private)"
show_json_output="$("$CLI" adapter show fixture-private --json)"
if python3 -c 'import json,sys; d=json.load(sys.stdin); assert len(d["adapters"]) == 1; assert d["adapters"][0]["id"] == "fixture-private"; assert d["adapters"][0]["route_count"] == 1; assert d["adapters"][0]["remote_resource_count"] == 1' <<<"$list_output" \
  && ! grep -q 'fixture-document' <<<"$list_output" \
  && [ "$show_output" = "$show_json_output" ] \
  && python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["id"] == "fixture-private"; assert d["env_allow"] == []; assert d["command"][0].endswith("/bin/adapter"); assert d["remote_resources"] == ["fixture-document:synthetic"]; assert d["routes"][0]["id"] == "edit-fixture-document"' <<<"$show_output"; then
  log_pass "list redacts remote identifiers while show preserves machine-local policy"
else
  log_fail "list redacts remote identifiers while show preserves machine-local policy" "$list_output $show_output"
fi

set +e
route_output="$("$CLI" adapter route --intent edit \
  --resource 'https://editor.fixture.invalid/document/synthetic?tab=one' --json 2>&1)"
route_rc=$?
set -e
if [ "$route_rc" -eq 0 ] \
  && python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["status"] == "matched"; assert d["adapter_id"] == "fixture-private"; assert d["route_id"] == "edit-fixture-document"; assert d["guide"].endswith("/AGENT_WORKFLOW.md"); assert "resource" not in d' <<<"$route_output"; then
  log_pass "route resolves provider-neutral manifest metadata without echoing the resource"
else
  log_fail "route resolves provider-neutral manifest metadata without echoing the resource" "$route_output"
fi

set +e
no_route_output="$("$CLI" adapter route --intent edit \
  --resource 'https://unmatched.fixture.invalid/document/synthetic' --json 2>&1)"
no_route_rc=$?
set -e
if [ "$no_route_rc" -eq 1 ] \
  && python3 -c 'import json,sys; d=json.load(sys.stdin); assert d == {"intent": "edit", "resource_kind": "url", "status": "no-match"}' <<<"$no_route_output" \
  && ! grep -q 'synthetic' <<<"$no_route_output"; then
  log_pass "route returns a content-free no-match for normal fallback handling"
else
  log_fail "route returns a content-free no-match for normal fallback handling" "$no_route_output"
fi

python3 - "$registry" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
data = json.loads(path.read_text())
data["adapters"]["fixture-second"] = dict(data["adapters"]["fixture-private"])
path.write_text(json.dumps(data))
PY
set +e
ambiguous_output="$("$CLI" adapter route --intent edit \
  --resource 'https://editor.fixture.invalid/document/synthetic' --json 2>&1)"
ambiguous_rc=$?
set -e
if [ "$ambiguous_rc" -eq 2 ] \
  && python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["status"] == "ambiguous"; assert len(d["matches"]) == 2' <<<"$ambiguous_output"; then
  log_pass "route fails closed when highest-priority registrations are ambiguous"
else
  log_fail "route fails closed when highest-priority registrations are ambiguous" "$ambiguous_output"
fi
python3 - "$registry" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
data = json.loads(path.read_text())
del data["adapters"]["fixture-second"]
path.write_text(json.dumps(data))
PY

request="$tmpdir/request.json"
receipt="$tmpdir/receipt.json"
cat > "$request" <<JSON
{
  "protocol": "llm-wiki-adapter/v1",
  "adapter_id": "fixture-private",
  "operation": "analyze",
  "arguments": {"case": "$inputs/case.json"},
  "output_dir": "$outputs/run"
}
JSON
set +e
run_output="$("$CLI" adapter run fixture-private --request "$request" --response "$receipt" --json 2>&1)"
run_rc=$?
set -e
if [ "$run_rc" -eq 0 ] \
  && [ -f "$outputs/run/packet.json" ] \
  && [ -f "$receipt" ] \
  && [ "$(python3 -c 'import os,sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$receipt")" = "0o600" ] \
  && python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["status"] == "ok"; assert d["artifacts"][0]["class"] == "wiki-safe"' <<<"$run_output"; then
  log_pass "run verifies artifact hashes and writes a private response receipt"
else
  log_fail "run verifies artifact hashes and writes a private response receipt" "$run_output"
fi

plan_sha="$(shasum -a 256 "$inputs/plan.json" | awk '{print $1}')"
remote_request="$tmpdir/remote-request.json"
remote_receipt="$outputs/remote-receipt.json"
cat > "$remote_request" <<JSON
{
  "protocol": "llm-wiki-adapter/v1",
  "adapter_id": "fixture-private",
  "operation": "suggest",
  "arguments": {
    "document_resource": "fixture-document:synthetic",
    "plan": "$inputs/plan.json"
  },
  "output_dir": "$outputs/remote-run",
  "remote_write": {
    "plan_sha256": "$plan_sha",
    "idempotency_key": "fixture-write-0001",
    "expected_revision": "revision-1"
  }
}
JSON

set +e
unapproved_output="$("$CLI" adapter run fixture-private --request "$remote_request" \
  --response "$remote_receipt" --json 2>&1)"
unapproved_rc=$?
set -e
if [ "$unapproved_rc" -ne 0 ] \
  && grep -q 'requires --approve-remote-write' <<<"$unapproved_output" \
  && [ ! -e "$outputs/remote-run/executed" ]; then
  log_pass "remote writes fail closed without an explicit exact-plan approval"
else
  log_fail "remote writes fail closed without an explicit exact-plan approval" "$unapproved_output"
fi

wrong_sha="$(printf wrong | shasum -a 256 | awk '{print $1}')"
set +e
mismatch_output="$("$CLI" adapter run fixture-private --request "$remote_request" \
  --response "$remote_receipt" --approve-remote-write "$wrong_sha" --json 2>&1)"
mismatch_rc=$?
set -e
if [ "$mismatch_rc" -ne 0 ] \
  && grep -q 'does not match remote_write plan_sha256' <<<"$mismatch_output" \
  && [ ! -e "$outputs/remote-run/executed" ]; then
  log_pass "remote write approval is bound to the exact plan hash"
else
  log_fail "remote write approval is bound to the exact plan hash" "$mismatch_output"
fi

set +e
receipt_scope_output="$("$CLI" adapter run fixture-private --request "$remote_request" \
  --response "$outside/remote-receipt.json" --approve-remote-write "$plan_sha" --json 2>&1)"
receipt_scope_rc=$?
set -e
if [ "$receipt_scope_rc" -ne 0 ] \
  && grep -q 'receipt is outside registered write roots' <<<"$receipt_scope_output" \
  && [ ! -e "$outputs/remote-run/executed" ]; then
  log_pass "remote write receipts must stay inside registered private output roots"
else
  log_fail "remote write receipts must stay inside registered private output roots" "$receipt_scope_output"
fi

set +e
remote_output="$("$CLI" adapter run fixture-private --request "$remote_request" \
  --response "$remote_receipt" --approve-remote-write "$plan_sha" --json 2>&1)"
remote_rc=$?
set -e
if [ "$remote_rc" -eq 0 ] \
  && [ -f "$remote_receipt" ] \
  && [ "$(python3 -c 'import os,sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$remote_receipt")" = "0o600" ] \
  && python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["remote_write"] == {"resource_count": 1, "status": "verified", "verified": True}; assert "summary" not in d; assert "run_id" not in d' <<<"$remote_output" \
  && ! grep -q 'DO NOT PRINT' <<<"$remote_output" \
  && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["remote_receipt"]["before_revision"] == "revision-1"; assert d["remote_receipt"]["verification"]["status"] == "verified"' "$remote_receipt"; then
  log_pass "approved remote writes produce a verified private receipt and redacted terminal report"
else
  log_fail "approved remote writes produce a verified private receipt and redacted terminal report" "$remote_output"
fi

set +e
timeout_output="$("$CLI" adapter doctor fixture-private --timeout 0 --json 2>&1)"
timeout_rc=$?
set -e
if [ "$timeout_rc" -ne 0 ] && grep -q 'timeout must be greater than zero' <<<"$timeout_output"; then
  log_pass "doctor rejects non-positive execution timeouts"
else
  log_fail "doctor rejects non-positive execution timeouts" "$timeout_output"
fi

cat > "$request" <<JSON
{
  "protocol": "llm-wiki-adapter/v1",
  "adapter_id": "fixture-private",
  "operation": "analyze",
  "arguments": {"case": "$inputs/case.json"},
  "output_dir": "$outside/run"
}
JSON
set +e
outside_output="$("$CLI" adapter run fixture-private --request "$request" --json 2>&1)"
outside_rc=$?
set -e
if [ "$outside_rc" -ne 0 ] \
  && grep -q 'outside registered write roots' <<<"$outside_output" \
  && [ ! -e "$outside/run" ]; then
  log_pass "run rejects output paths outside registered write roots before execution"
else
  log_fail "run rejects output paths outside registered write roots before execution" "$outside_output"
fi

printf '\n' >> "$adapter/.llm-wiki-adapter.json"
set +e
unavailable_route_output="$("$CLI" adapter route --intent edit \
  --resource 'https://editor.fixture.invalid/document/synthetic' --json 2>&1)"
unavailable_route_rc=$?
set -e
if [ "$unavailable_route_rc" -eq 2 ] \
  && python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["status"] == "unavailable"; assert d["issues"][0]["issue"] == "manifest changed"' <<<"$unavailable_route_output"; then
  log_pass "route blocks a matching registration after manifest drift"
else
  log_fail "route blocks a matching registration after manifest drift" "$unavailable_route_output"
fi
set +e
drift_output="$("$CLI" adapter doctor fixture-private --json 2>&1)"
drift_rc=$?
set -e
if [ "$drift_rc" -eq 1 ] \
  && python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["status"] == "unhealthy"; assert any("manifest changed" in x for x in d["issues"])' <<<"$drift_output"; then
  log_pass "doctor detects manifest drift and requires explicit re-registration"
else
  log_fail "doctor detects manifest drift and requires explicit re-registration" "$drift_output"
fi

set +e
remove_output="$("$CLI" adapter remove fixture-private --yes --json 2>&1)"
remove_rc=$?
set -e
if [ "$remove_rc" -eq 0 ] \
  && python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["status"] == "removed"' <<<"$remove_output" \
  && [ "$("$CLI" adapter list --json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["adapters"]))')" -eq 0 ]; then
  log_pass "remove deletes only the local registration"
else
  log_fail "remove deletes only the local registration" "$remove_output"
fi

printf '\n=== Results: %d/%d passed' "$PASS" "$TOTAL"
if [ "$FAIL" -gt 0 ]; then
  printf ', %d failed ===\n' "$FAIL"
  exit 1
fi
printf ' ===\n'
