#!/usr/bin/env bash
# Local-CI: verify the Codex plugin mirror (plugins/llm-wiki/) stays in sync
# with the Claude source of truth (claude-plugin/skills/wiki-manager/).
#
# Self-healing — on failure the sync script has ALREADY regenerated the
# Codex tree. The agent just needs to stage and commit the result.
#
# Why this exists: only LLMs work on this codebase, so drift between the
# two packaging targets must be caught inside the agent's edit→test loop
# rather than after a push to CI. See README "Claude-First, Codex-Compatible".
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

./scripts/sync-codex-plugin.sh >/dev/null

if ! git diff --quiet HEAD -- plugins/; then
  cat >&2 <<'MSG'
FAIL: Codex plugin mirror is out of sync with claude-plugin/skills/wiki-manager/.

The sync script has already regenerated plugins/llm-wiki/. To fix:
  1. git diff -- plugins/        # review the regenerated changes
  2. git add plugins/            # stage them alongside the Claude-side edit
  3. git commit                  # fold into the same commit
  4. ./tests/test-codex-sync.sh  # re-run to confirm clean

This guards against the Codex copy drifting from the Claude source.
MSG
  exit 1
fi

echo "OK: Codex plugin mirror is in sync."
