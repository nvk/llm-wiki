#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
BENCH="$ROOT/scripts/benchmark-token-efficiency"
FAKE_SERVER="$ROOT/tests/fixtures/fake-codex-app-server.py"
FAKE_CLAUDE="$ROOT/tests/fixtures/fake-claude-cli.py"
FAKE_PI="$ROOT/tests/fixtures/fake-pi-cli.py"

# A native Windows python cannot open a POSIX-style path: `/c/...` resolves
# against the current drive as `C:\c\...`. Translate when cygpath is present.
win_path() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi
}
FAKE_SERVER="$(win_path "$FAKE_SERVER")"
FAKE_CLAUDE="$(win_path "$FAKE_CLAUDE")"
FAKE_PI="$(win_path "$FAKE_PI")"

mkdir -p "$ROOT/.tmp"
TMP_ROOT="$(mktemp -d "$ROOT/.tmp/token-benchmark.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

echo "=== Token Efficiency Benchmarks ==="

"$BENCH" static --root "$ROOT" --check --output "$TMP_ROOT/static.json" >/dev/null
python3 - "$TMP_ROOT/static.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
assert report["kind"] == "static_context_budget"
assert report["passed"] is True
assert all(row["passed"] for row in report["metrics"].values())
print("  PASS: deterministic context budgets")
PY

python3 - "$ROOT/tests/budgets/token-budgets.json" "$TMP_ROOT/failing-budgets.json" <<'PY'
import json, sys
budgets = json.load(open(sys.argv[1]))
budgets["metrics"]["portable_protocol_bytes"]["max"] = 1
json.dump(budgets, open(sys.argv[2], "w"))
PY
if "$BENCH" static --root "$ROOT" --budgets "$TMP_ROOT/failing-budgets.json" \
  --check --output "$TMP_ROOT/static-failure.json" >/dev/null 2>&1; then
  echo "FAIL: static budget regression should fail" >&2
  exit 1
fi
echo "  PASS: static regression gate rejects over-budget context"

"$BENCH" live \
  --root "$ROOT" \
  --server-command "python3 '$FAKE_SERVER'" \
  --repeats 2 \
  --output "$TMP_ROOT/live.json" >/dev/null
python3 - "$TMP_ROOT/live.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
assert report["kind"] == "codex_app_server"
assert report["summary"]["passed"] is True
assert report["summary"]["turns"] == 6
assert report["summary"]["quality_passes"] == 6
assert report["summary"]["fixture_changed"] is False
assert len(report["cases_sha256"]) == 64
assert len(report["fixture_sha256"]) == 64
assert report["summary"]["cached_input_tokens"] > 0
assert report["summary"]["fixture_reads"] == 6
assert all(row["token_usage"]["input_tokens"] > 0 for row in report["runs"])
assert all(row["ttft_ms"] is not None for row in report["runs"])
assert all(row["quality"]["fixture_reads"] == 1 for row in report["runs"])
print("  PASS: app-server event and quality accounting")
PY

"$BENCH" live \
  --root "$ROOT" \
  --server-command "python3 '$FAKE_SERVER'" \
  --profile query \
  --case reliability-metrics \
  --output "$TMP_ROOT/codex-query.json" >/dev/null
python3 - "$TMP_ROOT/codex-query.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
assert report["summary"]["passed"] is True
assert report["profile"] == "query"
assert report["skill"] == "plugins/llm-wiki/skills/wiki-query/SKILL.md"
assert report["runs"][0]["quality"]["fixture_reads"] == 1
print("  PASS: Codex explicit read-only query preset")
PY

cp "$TMP_ROOT/live.json" "$TMP_ROOT/candidate.json"
"$BENCH" compare "$TMP_ROOT/live.json" "$TMP_ROOT/candidate.json" \
  --check --output "$TMP_ROOT/comparison.json" >/dev/null
python3 - "$TMP_ROOT/comparison.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
assert report["kind"] == "benchmark_comparison"
assert report["passed"] is True
assert report["metrics"]["uncached_input_tokens"]["delta_pct"] == 0.0
assert report["gates"]["same_case_corpus"] is True
assert report["gates"]["same_fixture_corpus"] is True
print("  PASS: paired report comparison and regression gates")
PY

python3 - "$TMP_ROOT/candidate.json" "$TMP_ROOT/candidate-regression.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
report["summary"]["passed"] = False
report["summary"]["quality_passes"] -= 1
json.dump(report, open(sys.argv[2], "w"))
PY
if "$BENCH" compare "$TMP_ROOT/live.json" "$TMP_ROOT/candidate-regression.json" \
  --check --output "$TMP_ROOT/comparison-failure.json" >/dev/null 2>&1; then
  echo "FAIL: quality regression should fail comparison" >&2
  exit 1
fi
echo "  PASS: comparison rejects quality regression"

python3 - "$TMP_ROOT/live.json" "$TMP_ROOT/candidate-wrong-profile.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
report["profile"] = "query"
json.dump(report, open(sys.argv[2], "w"))
PY
if "$BENCH" compare "$TMP_ROOT/live.json" "$TMP_ROOT/candidate-wrong-profile.json" \
  --check --output "$TMP_ROOT/comparison-profile-failure.json" >/dev/null 2>&1; then
  echo "FAIL: comparison should reject different harness profiles" >&2
  exit 1
fi
python3 - "$TMP_ROOT/comparison-profile-failure.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
assert report["gates"]["same_harness_mode"] is False
print("  PASS: comparison rejects mismatched harness profiles")
PY

python3 - "$TMP_ROOT/live.json" "$TMP_ROOT/candidate-wrong-corpus.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
report["cases_sha256"] = "0" * 64
json.dump(report, open(sys.argv[2], "w"))
PY
if "$BENCH" compare "$TMP_ROOT/live.json" "$TMP_ROOT/candidate-wrong-corpus.json" \
  --check --output "$TMP_ROOT/comparison-corpus-failure.json" >/dev/null 2>&1; then
  echo "FAIL: comparison should reject different case corpora" >&2
  exit 1
fi
python3 - "$TMP_ROOT/comparison-corpus-failure.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
assert report["gates"]["same_case_corpus"] is False
print("  PASS: comparison rejects mismatched case corpora")
PY

"$BENCH" pair \
  --baseline-root "$ROOT" \
  --candidate-root "$ROOT" \
  --output-dir "$TMP_ROOT/pair" \
  --server-command "python3 '$FAKE_SERVER'" \
  --case reliability-metrics >/dev/null
python3 - "$TMP_ROOT/pair/comparison.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
assert report["passed"] is True
print("  PASS: AB/BA pair orchestration")
PY

"$BENCH" claude-live \
  --root "$ROOT" \
  --claude-command "python3 '$FAKE_CLAUDE'" \
  --repeats 2 \
  --output "$TMP_ROOT/claude-live.json" >/dev/null
python3 - "$TMP_ROOT/claude-live.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
summary = report["summary"]
assert report["kind"] == "claude_code"
assert summary["passed"] is True
assert summary["turns"] == 6
assert summary["quality_passes"] == 6
assert summary["fixture_reads"] == 12
assert summary["cache_creation_input_tokens"] == 1200
assert summary["cache_read_input_tokens"] == 4800
assert summary["total_cost_usd"] == 0.3
assert all(row["permission_denials"] == [] for row in report["runs"])
print("  PASS: Claude stream, cache, cost, tool-evidence, and quality accounting")
PY

"$BENCH" claude-live \
  --root "$ROOT" \
  --claude-command "python3 '$FAKE_CLAUDE'" \
  --route command \
  --output "$TMP_ROOT/claude-command.json" >/dev/null
python3 - "$TMP_ROOT/claude-command.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
summary = report["summary"]
assert report["route"] == "command"
assert summary["passed"] is True
assert summary["turns"] == 3
assert all(row["tools_observed"] == ["Glob", "Grep", "Read"] for row in report["runs"])
assert all(row["quality"]["route"] == "command" for row in report["runs"])
print("  PASS: Claude real /wiki:query command route and read-only tools")
PY

"$BENCH" compare "$TMP_ROOT/claude-live.json" "$TMP_ROOT/claude-live.json" \
  --check --output "$TMP_ROOT/claude-comparison.json" >/dev/null
python3 - "$TMP_ROOT/claude-comparison.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
assert report["passed"] is True
assert report["metrics"]["total_cost_usd"]["delta_pct"] == 0.0
assert report["gates"]["cost_regression_within_pct"] is True
print("  PASS: Claude token and cost comparison gates")
PY

"$BENCH" claude-pair \
  --baseline-root "$ROOT" \
  --candidate-root "$ROOT" \
  --output-dir "$TMP_ROOT/claude-pair" \
  --claude-command "python3 '$FAKE_CLAUDE'" \
  --case reliability-metrics >/dev/null
python3 - "$TMP_ROOT/claude-pair/comparison.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
assert report["passed"] is True
print("  PASS: Claude AB/BA pair orchestration")
PY

"$BENCH" ds4-live \
  --root "$ROOT" \
  --pi-command "python3 '$FAKE_PI'" \
  --repeats 2 \
  --output "$TMP_ROOT/ds4-live.json" >/dev/null
python3 - "$TMP_ROOT/ds4-live.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
summary = report["summary"]
assert report["kind"] == "pi_ds4"
assert report["instruction"] == "profiles/query-lite/SKILL.md"
assert report["tool_surface"] == ["read", "grep", "find", "ls"]
assert summary["passed"] is True
assert summary["turns"] == 8
assert summary["quality_passes"] == 8
assert summary["fixture_reads"] == 16
assert summary["provider_requests"] == 16
assert summary["provider_payload_bytes"] > 0
assert all(row["ttft_ms"] is not None for row in report["runs"])
assert all(row["quality"]["read_only_tool_surface"] for row in report["runs"])
assert next(row for row in report["runs"] if row["case_id"] == "honest-gap")["quality"]["passed"]
print("  PASS: Pi/DS4 JSON, payload, tool-evidence, and quality accounting")
PY

if "$BENCH" ds4-live \
  --root "$ROOT" \
  --pi-command "env FAKE_PI_WRITE=1 python3 '$FAKE_PI'" \
  --case reliability-metrics \
  --output "$TMP_ROOT/ds4-write-failure.json" >/dev/null 2>&1; then
  echo "FAIL: DS4 benchmark should reject unexpected write-tool use" >&2
  exit 1
fi
python3 - "$TMP_ROOT/ds4-write-failure.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
run = report["runs"][0]
assert report["summary"]["passed"] is False
assert run["quality"]["read_only_tool_surface"] is False
assert run["quality"]["unexpected_tools_used"] == ["write"]
print("  PASS: DS4 benchmark rejects unexpected write-tool use")
PY

"$BENCH" ds4-pair \
  --root "$ROOT" \
  --output-dir "$TMP_ROOT/ds4-pair" \
  --pi-command "python3 '$FAKE_PI'" \
  --case reliability-metrics >/dev/null
python3 - "$TMP_ROOT/ds4-pair/comparison.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
assert report["passed"] is True
assert report["context_regression_metric"] == "provider_payload_bytes"
assert report["metrics"]["provider_payload_bytes"]["delta_pct"] < 0
assert report["gates"]["provider_payload_regression_within_pct"] is True
print("  PASS: DS4 full/lite AB/BA comparison uses measured provider payload")
PY

echo "OK: token benchmark suite passed."
