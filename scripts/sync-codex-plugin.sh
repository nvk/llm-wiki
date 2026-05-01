#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_SKILL="$ROOT/claude-plugin/skills/wiki-manager"
TARGET_PLUGIN="$ROOT/plugins/llm-wiki"
TARGET_SKILL="$TARGET_PLUGIN/skills/wiki"
CLAUDE_MANIFEST="$ROOT/claude-plugin/.claude-plugin/plugin.json"
CODEX_MANIFEST="$TARGET_PLUGIN/.codex-plugin/plugin.json"

if [ ! -d "$SOURCE_SKILL" ]; then
  echo "Missing source skill: $SOURCE_SKILL" >&2
  exit 1
fi

if [ ! -f "$CLAUDE_MANIFEST" ]; then
  echo "Missing Claude manifest: $CLAUDE_MANIFEST" >&2
  exit 1
fi

if [ ! -f "$CODEX_MANIFEST" ]; then
  echo "Missing Codex manifest: $CODEX_MANIFEST" >&2
  exit 1
fi

mkdir -p "$TARGET_PLUGIN/skills"
# The Codex marketplace caches plugin contents eagerly, so references/ must be
# copied into the generated tree rather than left as a symlink. agents/ is
# Codex-only metadata and is recreated below.
rm -rf "$TARGET_PLUGIN/skills/wiki-manager"
rsync -a --delete \
  --exclude='agents/' \
  --exclude='agents' \
  "$SOURCE_SKILL/" "$TARGET_SKILL/"

mkdir -p "$TARGET_SKILL/agents"

cat > "$TARGET_SKILL/agents/openai.yaml" <<'EOF'
interface:
  display_name: "Wiki Manager"
  short_description: "Initialize, ingest collections, compile, audit, query, research, and lint llm-wiki knowledge bases."
  brand_color: "#2F855A"
  default_prompt: "Research a topic and compile it into a structured wiki."

policy:
  allow_implicit_invocation: true
EOF

python3 - "$TARGET_SKILL" "$CLAUDE_MANIFEST" "$CODEX_MANIFEST" <<'PY'
import json
import re
import sys
from pathlib import Path

target_skill = Path(sys.argv[1])
claude_manifest = Path(sys.argv[2])
codex_manifest = Path(sys.argv[3])

skill_path = target_skill / "SKILL.md"
text = skill_path.read_text()

frontmatter = """---
name: wiki
description: >
  LLM-compiled knowledge base manager for Codex. Use it to initialize, ingest,
  import source collections, compile, query, lint, audit, research, plan, and generate outputs from topic-scoped wikis.
  Activates when the user mentions wiki workflows, knowledge-base management,
  ingestion, collection ingestion, import wiki, compilation, querying, linting, audit, research, librarian,
  scan quality, article quality, content review, output drift, provenance,
  implementation plan, or uses /wiki-style shorthand in a repo with .wiki/,
  ~/wiki/, or a configured hub path.
---
"""

start = text.find("---\n")
end = text.find("\n---\n", start + 4)
if start != 0 or end == -1:
    raise SystemExit(f"Unexpected frontmatter in {skill_path}")
text = frontmatter + text[end + 5 :]

replacements = [
    (
        "You manage an LLM-compiled knowledge base. Source documents are ingested into `raw/`, then incrementally compiled into a wiki of interconnected markdown articles. Claude Code is both the compiler and the query engine — no Obsidian, no external tools.\n",
        "You manage an LLM-compiled knowledge base. Source documents are ingested into `raw/`, then incrementally compiled into a wiki of interconnected markdown articles. Codex is both the compiler and the query engine.\n\n## Codex Plugin Notes\n\nCodex plugins package skills, MCP servers, apps, and metadata. They do not register Claude-style custom `/wiki:*` commands. Treat any `/wiki`, `/wiki:*`, or command-flag examples in this skill and its references as shorthand for the same workflow expressed in natural language, or via explicit `@wiki` invocation.\n",
    ),
    (
        "**Dual-linking for Obsidian + Claude.** Cross-references use both `[[wikilink]]` (for Obsidian graph view) and standard markdown `[text](path)` (for Claude navigation) on the same line: `[[slug|Name]] ([Name](../category/slug.md))`. Bidirectional when it makes sense.",
        "**Dual-linking for Obsidian + Codex.** Cross-references use both `[[wikilink]]` (for Obsidian graph view) and standard markdown `[text](path)` (for Codex navigation) on the same line: `[[slug|Name]] ([Name](../category/slug.md))`. Bidirectional when it makes sense.",
    ),
    (
        "When this skill activates outside of an explicit `/wiki:*` command:",
        "When this skill activates outside of an explicit `@wiki` invocation or `/wiki`-style shorthand:",
    ),
    (
        '4. If no relevant content → answer normally, optionally suggest: "This could be added to your wiki with `/wiki:ingest`"',
        '4. If no relevant content → answer normally, optionally suggest: "This could be added to your wiki; ask `@wiki` to ingest it."',
    ),
    (
        'Track uncompiled sources by comparing `raw/_index.md` ingestion dates against the last compile date in `_index.md`. If 5+ uncompiled sources exist after an ingestion, suggest: "You have N uncompiled sources. Run `/wiki:compile` to integrate them."',
        'Track uncompiled sources by comparing `raw/_index.md` ingestion dates against the last compile date in `_index.md`. If 5+ uncompiled sources exist after an ingestion, suggest: "You have N uncompiled sources. Ask `@wiki` to compile them."',
    ),
    (
        'Suggest `/wiki:lint --fix`, which will move contents to the appropriate topic wiki or quarantine to `inbox/.unknown/` per C11/C12 in `references/linting.md`.',
        'Suggest the `lint --fix` workflow, which will move contents to the appropriate topic wiki or quarantine to `inbox/.unknown/` per C11/C12 in `references/linting.md`.',
    ),
    (
        'Tell the user what\'s wrong and suggest `/wiki:lint --fix`.',
        "Tell the user what's wrong and suggest the equivalent of `lint --fix`.",
    ),
    (
        "Multiple Claude Code sessions can safely read and write to the same wiki simultaneously. No locks are needed.",
        "Multiple Codex sessions can safely read and write to the same wiki simultaneously. No locks are needed.",
    ),
    (
        'warn: "Stale research session found. Clean up with `/wiki:research` or delete manually."',
        'warn: "Stale research session found. Resume or rerun the research workflow, or delete it manually."',
    ),
]

for old, new in replacements:
    if old not in text:
        raise SystemExit(f"Expected text not found in {skill_path}: {old[:80]!r}")
    text = text.replace(old, new)

def replace_section(src, heading, replacement, next_heading=None):
    if next_heading is None:
        pattern = re.compile(rf"(?ms)^## {re.escape(heading)}\n.*\Z")
    else:
        pattern = re.compile(
            rf"(?ms)^## {re.escape(heading)}\n.*?(?=^## {re.escape(next_heading)}\n)"
        )
    if not pattern.search(src):
        raise SystemExit(f"Missing section heading in {skill_path}: {heading}")
    return pattern.sub(replacement, src, count=1)

text = replace_section(
    text,
    "Workflows",
    """## Workflows

Choose the smallest workflow that matches the request, then load only the
reference material you need for that workflow:

- `ingest` and `ingest-collection` → `references/ingestion.md`
- `compile` → `references/compilation.md` and `references/indexing.md`
- `query` → read the relevant `_index.md` files first, then only the articles
  needed to answer
- `lint` → `references/linting.md`
- `audit` → `references/audit.md`
- `research`, `plan`, `output`, `assess` → `references/research-infrastructure.md`
- `project` → `references/projects.md`
- `librarian` → `references/librarian.md`
- wiki structure, indexes, log format, file placement, init → `references/wiki-structure.md`
- hub lookup and path handling → `references/hub-resolution.md`

Keep the first response short and action-oriented. Read deeper references only
after the user intent is clear or a write action is needed.

""",
    next_heading="Links: File Paths and URLs",
)

text = replace_section(
    text,
    "Links: File Paths and URLs",
    """## Operational Rules

- Use absolute file paths in saved-output messages and markdown links for URLs.
- Append to `log.md` for every wiki write operation; never rewrite old log entries.
- Keep large writes chunked into multiple edits rather than one long generation.
- Read `_index.md` files before broader scans, and treat indexes as derived data.
- Use article `confidence` fields when answering and flag weak sourcing when seen.
- If structure or placement looks wrong, use the `lint --fix` workflow from
  `references/linting.md` instead of inventing a one-off repair path.

""",
)

skill_path.write_text(text)

# references/ is a copied mirror of claude-plugin/skills/wiki-manager/references
# and is shared verbatim — no per-file replacements needed. Source references
# use runtime-neutral wording ("the agent") so they read correctly under both.

claude = json.loads(claude_manifest.read_text())
codex = json.loads(codex_manifest.read_text())
codex["version"] = claude["version"]
codex["name"] = "wiki"
codex["license"] = claude.get("license", codex.get("license"))
codex["homepage"] = claude.get("homepage", codex.get("homepage", "https://github.com/nvk/llm-wiki"))
codex["repository"] = claude.get("repository", codex.get("repository", "https://github.com/nvk/llm-wiki"))
author = claude.get("author", {})
codex["author"] = {
    "name": author.get("name", "nvk"),
    "url": "https://github.com/nvk",
}
codex_manifest.write_text(json.dumps(codex, indent=2) + "\n")
PY

echo "Synced Codex plugin skill from Claude source."
echo "Source: $SOURCE_SKILL"
echo "Target: $TARGET_SKILL"
