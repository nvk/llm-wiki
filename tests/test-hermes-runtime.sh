#!/usr/bin/env bash
# Runtime test for the Hermes plugin: drive the adapter hooks directly (no full
# Hermes binary required in CI) and assert capture files + injected context.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN="$REPO_ROOT/plugins/llm-wiki-hermes"
TMP="$(mktemp -d)"
HUB="$TMP/hub"
PASS=0; FAIL=0

ok()  { PASS=$((PASS+1)); printf "  \033[32mPASS\033[0m: %s\n" "$1"; }
bad() { FAIL=$((FAIL+1)); printf "  \033[31mFAIL\033[0m: %s\n" "$1"; }

mkdir -p "$HUB/topics/nutrition"
# Hub-level index references the nutrition topic (token "gut" lives in topic index).
printf '# Hub\n- [Topics](topics/nutrition/) — nutrition wiki\n' > "$HUB/_index.md"
# Topic index contains the target article; query tokens "gut", "brain", "axis" match.
printf '# nutrition\n- [Gut-Brain Axis](concepts/gut.md) — links gut microbiome to cognition\n' > "$HUB/topics/nutrition/_index.md"

# Keep tests hermetic: a config that enables memory injection.
printf '{"memory": {"inject": true, "limit": 3}}' > "$HUB/config.json"

DRIVER="$TMP/driver.py"
cat > "$DRIVER" <<PY
import importlib.util, os, json, sys
from pathlib import Path

REPO_ROOT = Path("$REPO_ROOT")
PLUGIN = Path("$PLUGIN")
HUB = Path("$HUB")

# Load the real adapter + tools modules via importlib (mirrors existing test harness).
def _load(name, path):
    spec = importlib.util.spec_from_file_location(name, str(path))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

adapter = _load("hermes_adapter", PLUGIN / "hooks" / "adapter.py")
tools = _load("hermes_tools", PLUGIN / "tools.py")

# Load the shared engine and route it to our temp hub so tests are hermetic.
engine_path = REPO_ROOT / "plugins" / "llm-wiki" / "hooks" / "llm_wiki_session.py"
eng = _load("eng", engine_path)
eng.resolve_hub = lambda args: HUB
adapter._engine = eng

# 1) session start captures + returns (None when no rehydrate content)
r = adapter.on_session_start(session_id="h1", model="m", cwd="/x")
assert r is None or isinstance(r, str), "on_session_start return type"

# 2) pre_llm_call injects wiki memory for matching query
out = adapter.pre_llm_call(session_id="h2", user_message="gut brain axis", cwd="/x")
assert out and "Gut-Brain Axis" in out, f"memory not injected: {out!r}"

# 3) post_tool_call records without raising
assert adapter.post_tool_call(tool_name="terminal", result="x"*50, session_id="h3", cwd="/x") is None

# 4) state file written under harness=hermes
state = HUB / ".sessions" / "state" / "hermes" / "h2.json"
assert state.exists(), "state file missing"

# 5) wiki tool runs a deterministic CLI command against the hub (smoke)
res = json.loads(tools.handle_wiki({"command": "schema", "args": f"status {HUB / 'topics' / 'nutrition'}"}))
assert isinstance(res, dict), "tool must return JSON"

print("RUNTIME_OK")
PY

if python3 "$DRIVER" | grep -q "RUNTIME_OK"; then
  ok "hermes adapter driver completed"
else
  bad "hermes adapter driver failed (see output above)"
fi

echo "==========================================="
printf "Results: \033[32m%d passed\033[0m, \033[31m%d failed\033[0m, %d total\n" "$PASS" "$FAIL" "$((PASS+FAIL))"
rm -rf "$TMP"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
