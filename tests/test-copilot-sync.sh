#!/usr/bin/env bash
# Local-CI: verify the generated GitHub Copilot plugin and marketplace entry
# stay in sync with the Claude source of truth.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

./scripts/sync-copilot-plugin.sh >/dev/null

if ! git diff --quiet HEAD -- plugins/llm-wiki-copilot/ .github/plugin/marketplace.json \
  || [ -n "$(git ls-files --others --exclude-standard -- plugins/llm-wiki-copilot/ .github/plugin/marketplace.json)" ]; then
  cat >&2 <<'MSG'
FAIL: GitHub Copilot plugin output is out of sync with the Claude source.

The sync script has already regenerated plugins/llm-wiki-copilot/ and
.github/plugin/marketplace.json. Review and stage those generated files with
the canonical source edit, then re-run this test.
MSG
  exit 1
fi

echo "OK: GitHub Copilot plugin mirror is in sync."