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

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
mkdir -p \
  "$scratch/scripts" \
  "$scratch/claude-plugin/skills/wiki-manager/references" \
  "$scratch/claude-plugin/.claude-plugin" \
  "$scratch/plugins/llm-wiki-opencode/skills/wiki-query"
cp scripts/sync-opencode-plugin.sh "$scratch/scripts/"
touch \
  "$scratch/claude-plugin/skills/wiki-manager/references/query-lite.md" \
  "$scratch/claude-plugin/.claude-plugin/plugin.json" \
  "$scratch/scripts/llm-wiki" \
  "$scratch/plugins/llm-wiki-opencode/skills/wiki-query/must-survive"
# Prerequisite checks must fail before anything in the target tree is
# touched. Removing the source skill is the cheapest way to prove it.
mv "$scratch/claude-plugin/skills/wiki-manager" "$scratch/claude-plugin/skills/absent"
set +e
missing_source_output="$(/bin/bash "$scratch/scripts/sync-opencode-plugin.sh" 2>&1)"
missing_source_rc=$?
set -e
mv "$scratch/claude-plugin/skills/absent" "$scratch/claude-plugin/skills/wiki-manager"
if [ "$missing_source_rc" -eq 0 ] \
  || ! grep -q "Missing source skill" <<<"$missing_source_output" \
  || [ ! -f "$scratch/plugins/llm-wiki-opencode/skills/wiki-query/must-survive" ]; then
  echo "FAIL: OpenCode sync must reject a missing source before changing the target." >&2
  echo "$missing_source_output" >&2
  exit 1
fi

./scripts/sync-opencode-plugin.sh >/dev/null

# The references link must survive a sync. Rewriting it on every run breaks
# checkouts on platforms where `ln -s` cannot actually create one.
#
# Two representations are correct, and which one is on disk is git's choice, not
# the sync script's: a real symlink where the platform supports them, and the
# regular file holding the link target that git checks out when core.symlinks is
# false. Both must be left alone; what must never appear is a directory copy.
REFERENCES="plugins/llm-wiki-opencode/skills/wiki-manager/references"
if [ -d "$REFERENCES" ] && [ ! -L "$REFERENCES" ]; then
  cat >&2 <<'MSG'
FAIL: the OpenCode references link was replaced by a directory copy.

sync-opencode-plugin.sh must leave the tracked link - symlink or placeholder
file - exactly as git checked it out.
MSG
  exit 1
fi

if [ "$(git ls-files -s -- "$REFERENCES" | cut -d' ' -f1)" != "120000" ]; then
  echo "FAIL: $REFERENCES is no longer tracked as a link." >&2
  exit 1
fi

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

echo "OK: OpenCode sync prerequisites are non-destructive and the plugin mirror is in sync."
