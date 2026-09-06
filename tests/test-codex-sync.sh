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

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
mkdir -p \
  "$scratch/scripts" \
  "$scratch/claude-plugin/skills/wiki-manager/references" \
  "$scratch/claude-plugin/.claude-plugin" \
  "$scratch/plugins/llm-wiki/.codex-plugin" \
  "$scratch/plugins/llm-wiki/skills/wiki-query"
cp scripts/sync-codex-plugin.sh "$scratch/scripts/"
touch \
  "$scratch/claude-plugin/skills/wiki-manager/references/query-lite.md" \
  "$scratch/claude-plugin/.claude-plugin/plugin.json" \
  "$scratch/plugins/llm-wiki/.codex-plugin/plugin.json" \
  "$scratch/scripts/llm-wiki-session" \
  "$scratch/scripts/llm-wiki" \
  "$scratch/plugins/llm-wiki/skills/wiki-query/must-survive"
# Prerequisite checks must fail before anything in the target tree is
# touched. Removing the source skill is the cheapest way to prove it.
mv "$scratch/claude-plugin/skills/wiki-manager" "$scratch/claude-plugin/skills/absent"
set +e
missing_source_output="$(/bin/bash "$scratch/scripts/sync-codex-plugin.sh" 2>&1)"
missing_source_rc=$?
set -e
mv "$scratch/claude-plugin/skills/absent" "$scratch/claude-plugin/skills/wiki-manager"
if [ "$missing_source_rc" -eq 0 ] \
  || ! grep -q "Missing source skill" <<<"$missing_source_output" \
  || [ ! -f "$scratch/plugins/llm-wiki/skills/wiki-query/must-survive" ]; then
  echo "FAIL: Codex sync must reject a missing source before changing the target." >&2
  echo "$missing_source_output" >&2
  exit 1
fi

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

echo "OK: Codex sync prerequisites are non-destructive and the plugin mirror is in sync."
