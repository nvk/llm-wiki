#!/usr/bin/env bash
# Local-CI: verify the OpenCode plugin mirror (plugins/llm-wiki-opencode/)
# stays in sync with the Claude source of truth (claude-plugin/skills/wiki-manager/).
#
# Self-healing — on failure the sync script has ALREADY regenerated the
# OpenCode tree. The agent just needs to stage and commit the result.
#
# Mirrors test-codex-sync.sh for the Codex target.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

./scripts/sync-opencode-plugin.sh >/dev/null

if ! git diff --quiet HEAD -- plugins/llm-wiki-opencode/; then
  cat >&2 <<'MSG'
FAIL: OpenCode plugin mirror is out of sync with claude-plugin/skills/wiki-manager/.

The sync script has already regenerated plugins/llm-wiki-opencode/. To fix:
  1. git diff -- plugins/llm-wiki-opencode/   # review the regenerated changes
  2. git add plugins/llm-wiki-opencode/        # stage them
  3. git commit                                # fold into the same commit
  4. ./tests/test-opencode-sync.sh             # re-run to confirm clean

This guards against the OpenCode copy drifting from the Claude source.
MSG
  exit 1
fi

echo "OK: OpenCode plugin mirror is in sync."
