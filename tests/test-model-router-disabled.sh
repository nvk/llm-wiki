#!/usr/bin/env bash
# Prove the experimental model router is dormant by default.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

unset LLM_WIKI_MODEL_ROUTER
unset LLM_WIKI_MODEL_ROUTER_CONFIG

STATUS="$(./scripts/wiki-router status)"
echo "$STATUS" | python3 -c 'import json,sys; data=json.load(sys.stdin); assert data["enabled"] is False'

if ./scripts/wiki-router chat --role synthesize --prompt "hello" >/tmp/llm-wiki-router-disabled.out 2>/tmp/llm-wiki-router-disabled.err; then
  echo "FAIL: live chat call unexpectedly succeeded with router disabled" >&2
  exit 1
fi

if ! grep -Eq "Router is disabled by default|model router config not found|model router disabled" /tmp/llm-wiki-router-disabled.err; then
  echo "FAIL: disabled router error did not explain opt-in behavior" >&2
  cat /tmp/llm-wiki-router-disabled.err >&2
  exit 1
fi

grep -q "Only use this workflow when" claude-plugin/skills/wiki-manager/references/model-router.md
grep -q "Router is opt-in and disabled by default" claude-plugin/skills/wiki-manager/references/model-router.md

echo "OK: model router is dormant by default."

