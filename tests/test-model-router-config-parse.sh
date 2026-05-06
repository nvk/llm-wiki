#!/usr/bin/env bash
# Validate the packaged example config and dry-run payload generation.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONFIG="examples/model-router.yaml"

STATUS="$(LLM_WIKI_MODEL_ROUTER=1 ./scripts/wiki-router --config "$CONFIG" status)"
echo "$STATUS" | python3 -c '
import json,sys
data=json.load(sys.stdin)
assert data["enabled"] is True
assert "synthesize" in data["roles"]
assert "compiler" in data["roles"]
assert "embed" in data["roles"]
assert "rerank" in data["roles"]
'

CHAT="$(./scripts/wiki-router --config "$CONFIG" --dry-run chat --role synthesize --prompt "Summarize this wiki source.")"
echo "$CHAT" | python3 -c '
import json,sys
data=json.load(sys.stdin)
assert data["dry_run"] is True
assert data["kind"] == "chat"
assert data["model"] == "qwen3.6-35b-a3b"
assert data["endpoint"].endswith("/chat/completions")
'

EMBED="$(./scripts/wiki-router --config "$CONFIG" --dry-run embed --prompt "raw source text")"
echo "$EMBED" | python3 -c '
import json,sys
data=json.load(sys.stdin)
assert data["kind"] == "embed"
assert data["model"] == "qwen3-embedding-8b"
assert data["endpoint"].endswith("/embeddings")
'

RERANK="$(./scripts/wiki-router --config "$CONFIG" --dry-run rerank --query "claim" --documents-json '["source a", "source b"]')"
echo "$RERANK" | python3 -c '
import json,sys
data=json.load(sys.stdin)
assert data["kind"] == "rerank"
assert data["model"] == "qwen3-reranker-8b"
assert data["payload"]["documents"] == ["source a", "source b"]
'

echo "OK: model router example config parses and dry-run payloads are valid."

