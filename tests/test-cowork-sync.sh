#!/bin/bash
# Verify the Cowork plugin mirror matches the Claude source.
# Self-healing: the sync script has already regenerated cowork/ if this fails.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Re-sync from Claude source
"$PROJECT_ROOT/scripts/sync-cowork-plugin.sh" >/dev/null

# Check for uncommitted changes
if ! git diff --quiet HEAD -- cowork/; then
  cat >&2 <<'MSG'
FAIL: Cowork plugin mirror is out of sync with claude-plugin/skills/wiki-manager/.

The sync script has already regenerated cowork/. To fix:
  1. git diff -- cowork/           # review the regenerated changes
  2. git add cowork/               # stage them alongside the Claude-side edit
  3. git commit                    # fold into the same commit
  4. ./tests/test-cowork-sync.sh   # re-run to confirm clean

This guards against the Cowork copy drifting from the Claude source.
MSG
  exit 1
fi

echo "OK: Cowork plugin mirror is in sync."
