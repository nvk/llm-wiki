#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="$ROOT/profiles/query-lite/SKILL.md"

digest() {
  python3 - "$1" <<'PY'
import hashlib, sys
print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())
PY
}

before="$(digest "$TARGET")"
"$ROOT/scripts/sync-query-lite-profile.sh" >/dev/null
after="$(digest "$TARGET")"

if [[ "$before" != "$after" ]]; then
  echo "FAIL: profiles/query-lite/SKILL.md was stale and has been regenerated." >&2
  exit 1
fi

python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
source = (root / "claude-plugin/skills/wiki-manager/references/query-lite.md").read_text()
marker = "\n---\n\n"
targets = [
    root / "profiles/query-lite/SKILL.md",
    root / "plugins/llm-wiki/skills/wiki-query/SKILL.md",
    root / "plugins/llm-wiki-opencode/skills/wiki-query/SKILL.md",
    root / "plugins/llm-wiki-copilot/skills/wiki-manager/references/query-lite.md",
]
for target_path in targets:
    target = target_path.read_text()
    if target_path.name == "query-lite.md":
        if target != source:
            raise SystemExit(
                f"FAIL: {target_path.relative_to(root)} differs from canonical query protocol"
            )
        continue
    if marker not in target:
        raise SystemExit(f"FAIL: {target_path.relative_to(root)} has invalid frontmatter")
    body = target.split(marker, 1)[1]
    if body != source:
        raise SystemExit(
            f"FAIL: {target_path.relative_to(root)} differs from canonical query protocol"
        )
print("OK: portable and generated query-lite profiles are in sync.")
PY

if ! grep -q '^allowed-tools: Read, Glob, Grep$' "$ROOT/claude-plugin/commands/query.md"; then
  echo "FAIL: Claude /wiki:query command is not restricted to read-only tools" >&2
  exit 1
fi

pi_dry_run="$(PI_CLI="/tmp/fake-pi-cli.js" "$ROOT/scripts/pi-wiki-query" --dry-run "test query")"
if [[ "$pi_dry_run" != *"--tools read\\,grep\\,find\\,ls"* \
   || "$pi_dry_run" != *"profiles/query-lite/SKILL.md"* \
   || "$pi_dry_run" != *"--no-extensions"* \
   || "$pi_dry_run" != *"--no-skills"* ]]; then
  echo "FAIL: generic Pi launcher dry run is missing query-only settings" >&2
  echo "$pi_dry_run" >&2
  exit 1
fi
if [[ "$pi_dry_run" == *"edit"* || "$pi_dry_run" == *"write"* ]]; then
  echo "FAIL: generic Pi query launcher exposed write-capable tools" >&2
  exit 1
fi
echo "OK: generic Pi query launcher uses a read-only isolated prompt surface."

tmp="$(mktemp -d "${TMPDIR:-/tmp}/llm-wiki-ds4-launcher.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
dry_run="$(
  PI_CLI="$tmp/fake-pi-cli.js" \
  PI_CODING_AGENT_DIR="$tmp/pi" \
  "$ROOT/scripts/pi-ds4-wiki-query" --dry-run "test query"
)"

python3 - "$tmp/pi/models.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
model = data["providers"]["ds4"]["models"][0]
assert model["id"] == "deepseek-v4-flash"
assert model["contextWindow"] == 85000
assert model["maxTokens"] == 4096
PY

if [[ "$dry_run" != *"--tools read\\,grep\\,find\\,ls"* \
   || "$dry_run" != *"profiles/query-lite/SKILL.md"* \
   || "$dry_run" != *"profiles/ds4/pi-query-tools.ts"* ]]; then
  echo "FAIL: DS4 launcher dry run is missing the query-only preset" >&2
  echo "$dry_run" >&2
  exit 1
fi
if [[ "$dry_run" == *"edit"* || "$dry_run" == *"write"* ]]; then
  echo "FAIL: DS4 query launcher exposed write-capable tools" >&2
  exit 1
fi
echo "OK: DS4 query launcher uses isolated read-only settings."
