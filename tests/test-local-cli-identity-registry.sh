#!/bin/bash
# Validate that identity assign --apply refuses an unusable explicitly selected
# hub registry instead of writing a config identity the registry never learns.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CLI="$PROJECT_ROOT/scripts/llm-wiki"
PASS=0
FAIL=0
TOTAL=0

log_pass() { PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[32mPASS\033[0m: %s\n" "$1"; }
log_fail() { FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[31mFAIL\033[0m: %s - %s\n" "$1" "$2"; }

echo "=== Local llm-wiki identity assign registry ==="

set +e
registry_output="$(python3 - "$CLI" <<'PY' 2>&1
import json
import runpy
import sys
import tempfile
from pathlib import Path
from types import SimpleNamespace

script = sys.argv[1]


def make_hub(base, registry):
    hub = base / "hub"
    topic = hub / "topics" / "topic"
    topic.mkdir(parents=True)
    (hub / "_index.md").write_text("# Hub\n", encoding="utf-8")
    (hub / "log.md").write_text("# Log\n", encoding="utf-8")
    (topic / "_index.md").write_text("# Topic\n", encoding="utf-8")
    (topic / "config.md").write_text("---\ntitle: Example\n---\nbody\n", encoding="utf-8")
    if registry is not None:
        (hub / "wikis.json").write_text(json.dumps(registry, indent=2) + "\n", encoding="utf-8")
    return hub, topic


def args_for(topic, hub):
    return SimpleNamespace(
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


def run_case(namespace, registry, expect_error, label):
    with tempfile.TemporaryDirectory() as tmp:
        hub, topic = make_hub(Path(tmp), registry)
        before = (topic / "config.md").read_text(encoding="utf-8")
        raised = None
        try:
            namespace["run_identity"](args_for(topic, hub))
        except SystemExit as exc:
            raised = exc
        after = (topic / "config.md").read_text(encoding="utf-8")
        if expect_error:
            assert raised is not None, f"{label}: expected SystemExit, got success"
            assert after == before, f"{label}: config.md was written anyway:\n{after}"
        else:
            assert raised is None, f"{label}: unexpected SystemExit {raised}"
            assert 'wiki_id: "wk-2222222222222222"' in after, after
            data = json.loads((hub / "wikis.json").read_text(encoding="utf-8"))
            assert data["wikis"]["topic"]["id"] == "wk-2222222222222222", data


namespace = runpy.run_path(script)
run_case(namespace, {"default": "<HUB>", "wikis": []}, True, "invalid wikis shape")
run_case(namespace, None, True, "missing wikis.json")
run_case(
    namespace,
    {"default": "<HUB>", "wikis": {"topic": {"path": "topics/topic"}}},
    False,
    "valid registry",
)
PY
)"
registry_rc=$?
set -e
if [ "$registry_rc" -eq 0 ]; then
  log_pass "identity assign refuses an unusable explicit hub registry"
else
  log_fail "identity assign refuses an unusable explicit hub registry" "$registry_output"
fi

echo ""
echo "==========================================="
printf "Results: \033[32m%d passed\033[0m, \033[31m%d failed\033[0m, %d total\n" "$PASS" "$FAIL" "$TOTAL"

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
