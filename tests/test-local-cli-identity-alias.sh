#!/bin/bash
# Validate that an explicit identity replacement reaches every registry name that
# points at the same wiki root, not just the first one.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CLI="$PROJECT_ROOT/scripts/llm-wiki"
PASS=0
FAIL=0
TOTAL=0

log_pass() { PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[32mPASS\033[0m: %s\n" "$1"; }
log_fail() { FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[31mFAIL\033[0m: %s - %s\n" "$1" "$2"; }

echo "=== Local llm-wiki identity aliases ==="

set +e
alias_output="$(python3 - "$CLI" <<'PY' 2>&1
import json
import runpy
import sys
import tempfile
from pathlib import Path
from types import SimpleNamespace

script = sys.argv[1]

with tempfile.TemporaryDirectory() as tmp:
    hub = Path(tmp) / "hub"
    topic = hub / "topics" / "topic"
    topic.mkdir(parents=True)
    (hub / "_index.md").write_text("# Hub\n", encoding="utf-8")
    (hub / "log.md").write_text("# Log\n", encoding="utf-8")
    (topic / "_index.md").write_text("# Topic\n", encoding="utf-8")
    (topic / "config.md").write_text(
        "---\ntitle: Example\nwiki_id: wk-1111111111111111\n---\nbody\n", encoding="utf-8"
    )
    registry = {
        "default": "<HUB>",
        "wikis": {
            "alias": {"path": "topics/topic", "id": "wk-1111111111111111"},
            "topic": {"path": "topics/topic", "id": "wk-1111111111111111"},
        },
    }
    (hub / "wikis.json").write_text(json.dumps(registry, indent=2) + "\n", encoding="utf-8")

    namespace = runpy.run_path(script)
    namespace["run_identity"](
        SimpleNamespace(
            path=None,
            local=False,
            wiki="topic",
            hub=str(hub),
            identity_command="assign",
            id="wk-2222222222222222",
            replace=True,
            apply=True,
            json=True,
            allow_identity_mismatch=False,
            include_archived=False,
        )
    )

    data = json.loads((hub / "wikis.json").read_text(encoding="utf-8"))
    config = (topic / "config.md").read_text(encoding="utf-8")
    assert data["wikis"]["alias"]["id"] == "wk-2222222222222222", data["wikis"]["alias"]
    assert data["wikis"]["topic"]["id"] == "wk-2222222222222222", data["wikis"]["topic"]
    assert 'wiki_id: "wk-2222222222222222"' in config, config
    assert namespace["identity_payload"](topic, hub)["status"] == "match"
PY
)"
alias_rc=$?
set -e
if [ "$alias_rc" -eq 0 ]; then
  log_pass "identity replace reaches every name that points at the same root"
else
  log_fail "identity replace reaches every name that points at the same root" "$alias_output"
fi

echo ""
echo "==========================================="
printf "Results: \033[32m%d passed\033[0m, \033[31m%d failed\033[0m, %d total\n" "$PASS" "$FAIL" "$TOTAL"

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
