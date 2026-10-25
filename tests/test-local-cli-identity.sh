#!/bin/bash
# Validate identity-assign write ordering: a failed registry write must not leave
# config.md rebound to an identity the registry does not know.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CLI="$PROJECT_ROOT/scripts/llm-wiki"
PASS=0
FAIL=0
TOTAL=0

log_pass() { PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[32mPASS\033[0m: %s\n" "$1"; }
log_fail() { FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[31mFAIL\033[0m: %s - %s\n" "$1" "$2"; }

echo "=== Local llm-wiki identity assign ==="

set +e
atomic_output="$(python3 - "$CLI" <<'PY' 2>&1
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
    (hub / "wikis.json").write_text(
        json.dumps(
            {
                "default": "<HUB>",
                "wikis": {"topic": {"path": "topics/topic", "id": "wk-1111111111111111"}},
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    before_config = (topic / "config.md").read_text(encoding="utf-8")
    before_registry = (hub / "wikis.json").read_text(encoding="utf-8")

    ns = runpy.run_path(script)

    def failing_registry_write(*_args, **_kwargs):
        raise PermissionError("synthetic registry lock")

    ns["run_identity"].__globals__["write_registry"] = failing_registry_write

    args = SimpleNamespace(
        path=str(topic),
        local=False,
        wiki=None,
        hub=str(hub),
        identity_command="assign",
        id="wk-2222222222222222",
        replace=True,
        apply=True,
        json=True,
        allow_identity_mismatch=False,
        include_archived=False,
    )

    raised = None
    try:
        ns["run_identity"](args)
    except BaseException as exc:  # noqa: BLE001 - the failure is the assertion
        raised = exc
    assert isinstance(raised, PermissionError), raised
    assert (topic / "config.md").read_text(encoding="utf-8") == before_config
    assert (hub / "wikis.json").read_text(encoding="utf-8") == before_registry
PY
)"
atomic_rc=$?
set -e
if [ "$atomic_rc" -eq 0 ]; then
  log_pass "a failed registry write leaves config.md and wikis.json unchanged"
else
  log_fail "a failed registry write leaves config.md and wikis.json unchanged" "$atomic_output"
fi

echo ""
echo "==========================================="
printf "Results: \033[32m%d passed\033[0m, \033[31m%d failed\033[0m, %d total\n" "$PASS" "$FAIL" "$TOTAL"

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
