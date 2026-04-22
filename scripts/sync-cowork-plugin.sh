#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_SKILL="$ROOT/claude-plugin/skills/wiki-manager"
TARGET_PLUGIN="$ROOT/cowork"
TARGET_SKILL="$TARGET_PLUGIN/skills/wiki-manager"
CLAUDE_MANIFEST="$ROOT/claude-plugin/.claude-plugin/plugin.json"
COWORK_MANIFEST="$TARGET_PLUGIN/.claude-plugin/plugin.json"

if [ ! -d "$SOURCE_SKILL" ]; then
  echo "Missing source skill: $SOURCE_SKILL" >&2
  exit 1
fi

if [ ! -f "$CLAUDE_MANIFEST" ]; then
  echo "Missing Claude manifest: $CLAUDE_MANIFEST" >&2
  exit 1
fi

if [ ! -f "$COWORK_MANIFEST" ]; then
  echo "Missing Cowork manifest: $COWORK_MANIFEST" >&2
  exit 1
fi

mkdir -p "$TARGET_PLUGIN/skills"
# references/ is a symlink into the Claude source — exclude from rsync so it's
# preserved, and recreate it idempotently below.
rsync -a --delete \
  --exclude='references/' \
  --exclude='references' \
  "$SOURCE_SKILL/" "$TARGET_SKILL/"

# Recreate the references symlink (idempotent).
rm -rf "$TARGET_SKILL/references"
ln -s "../../../claude-plugin/skills/wiki-manager/references" "$TARGET_SKILL/references"

python3 - "$TARGET_SKILL" "$CLAUDE_MANIFEST" "$COWORK_MANIFEST" <<'PY'
import json
import sys
from pathlib import Path

target_skill = Path(sys.argv[1])
claude_manifest = Path(sys.argv[2])
cowork_manifest = Path(sys.argv[3])

skill_path = target_skill / "SKILL.md"
text = skill_path.read_text()

# Replace frontmatter with Cowork-specific version
frontmatter = """---
name: wiki-manager
description: >
  Knowledge base for non-technical teams. Research topics, build wikis,
  ask questions, and generate reports — all in natural language. Mount
  your wiki folder in Cowork to get started. Also activates when user
  says "wiki", "knowledge base", "research", "what do we know about",
  or asks a factual question in a session with a mounted wiki folder.
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - WebFetch
  - WebSearch
---
"""

start = text.find("---\n")
end = text.find("\n---\n", start + 4)
if start != 0 or end == -1:
    raise SystemExit(f"Unexpected frontmatter in {skill_path}")
text = frontmatter + text[end + 5 :]

replacements = [
    # Core identity
    (
        "You manage an LLM-compiled knowledge base. Source documents are ingested into `raw/`, then incrementally compiled into a wiki of interconnected markdown articles. Claude Code is both the compiler and the query engine — no Obsidian, no external tools.\n",
        "You manage an LLM-compiled knowledge base. Source documents are ingested into `raw/`, then incrementally compiled into a wiki of interconnected markdown articles. Claude Cowork is both the compiler and the query engine.\n\n## Cowork Notes\n\nCowork runs inside a local VM. Only folders mounted via the Cowork folder picker are visible. When resolving the wiki hub path, check mounted folder roots for `_index.md` before falling back to `~/wiki/`. iCloud and cloud-synced paths may not work reliably — use a local folder.\n\nIf no wiki is found, guide the user: \"Mount a folder in Cowork's folder picker, then tell me what you'd like to research.\"\n",
    ),
    # Dual-linking
    (
        "**Dual-linking for Obsidian + Claude.** Cross-references use both `[[wikilink]]` (for Obsidian graph view) and standard markdown `[text](path)` (for Claude navigation) on the same line: `[[slug|Name]] ([Name](../category/slug.md))`. Bidirectional when it makes sense.",
        "**Dual-linking for Obsidian + Cowork.** Cross-references use both `[[wikilink]]` (for Obsidian graph view) and standard markdown `[text](path)` (for Cowork navigation) on the same line: `[[slug|Name]] ([Name](../category/slug.md))`. Bidirectional when it makes sense.",
    ),
    # Ambient behavior
    (
        "When this skill activates outside of an explicit `/wiki:*` command:",
        "When this skill activates outside of an explicit wiki command:",
    ),
    # Suggestions
    (
        '4. If no relevant content → answer normally, optionally suggest: "This could be added to your wiki with `/wiki:ingest`"',
        '4. If no relevant content → answer normally, optionally suggest: "This could be added to your wiki — just paste the URL or text."',
    ),
    # Compilation nudge
    (
        'Track uncompiled sources by comparing `raw/_index.md` ingestion dates against the last compile date in `_index.md`. If 5+ uncompiled sources exist after an ingestion, suggest: "You have N uncompiled sources. Run `/wiki:compile` to integrate them."',
        'Track uncompiled sources by comparing `raw/_index.md` ingestion dates against the last compile date in `_index.md`. If 5+ uncompiled sources exist after an ingestion, suggest: "You have N uncompiled sources. Want me to compile them into articles?"',
    ),
    # Lint suggestions
    (
        'Suggest `/wiki:lint --fix`, which will move contents to the appropriate topic wiki or quarantine to `inbox/.unknown/` per C11/C12 in `references/linting.md`.',
        'Suggest running a health check to fix the issue.',
    ),
    (
        "Tell the user what's wrong and suggest `/wiki:lint --fix`.",
        "Tell the user what's wrong and offer to fix it.",
    ),
    # Concurrency
    (
        "Multiple Claude Code sessions can safely read and write to the same wiki simultaneously. No locks are needed.",
        "Multiple Cowork sessions can safely read and write to the same wiki simultaneously. No locks are needed.",
    ),
    # Session cleanup
    (
        'warn: "Stale research session found. Clean up with `/wiki:research` or delete manually."',
        'warn: "Stale research session found. Want to resume it or start fresh?"',
    ),
]

for old, new in replacements:
    if old not in text:
        raise SystemExit(f"Expected text not found in {skill_path}: {old[:80]!r}")
    text = text.replace(old, new)

skill_path.write_text(text)

# Sync version from Claude manifest
claude = json.loads(claude_manifest.read_text())
cowork = json.loads(cowork_manifest.read_text())
cowork["version"] = claude["version"]
cowork_manifest.write_text(json.dumps(cowork, indent=2) + "\n")
PY

echo "Synced Cowork plugin skill from Claude source."
echo "Source: $SOURCE_SKILL"
echo "Target: $TARGET_SKILL"
