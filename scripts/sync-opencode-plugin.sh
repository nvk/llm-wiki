#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_SKILL="$ROOT/claude-plugin/skills/wiki-manager"
QUERY_SOURCE="$SOURCE_SKILL/references/query-lite.md"
TARGET_PLUGIN="$ROOT/plugins/llm-wiki-opencode"
TARGET_SKILL="$TARGET_PLUGIN/skills/wiki-manager"
TARGET_QUERY="$TARGET_PLUGIN/skills/wiki-query"
CLAUDE_MANIFEST="$ROOT/claude-plugin/.claude-plugin/plugin.json"
LOCAL_HELPER="$ROOT/scripts/llm-wiki"

if [ ! -d "$SOURCE_SKILL" ]; then
  echo "Missing source skill: $SOURCE_SKILL" >&2
  exit 1
fi

if [ ! -f "$QUERY_SOURCE" ]; then
  echo "Missing query-lite source: $QUERY_SOURCE" >&2
  exit 1
fi

if [ ! -f "$CLAUDE_MANIFEST" ]; then
  echo "Missing Claude manifest: $CLAUDE_MANIFEST" >&2
  exit 1
fi

if [ ! -f "$LOCAL_HELPER" ]; then
  echo "Missing local helper: $LOCAL_HELPER" >&2
  exit 1
fi

mkdir -p "$ROOT/claude-plugin/bin" "$TARGET_PLUGIN/bin"
cp "$LOCAL_HELPER" "$ROOT/claude-plugin/bin/llm-wiki"
cp "$LOCAL_HELPER" "$TARGET_PLUGIN/bin/llm-wiki"
chmod 0755 "$ROOT/claude-plugin/bin/llm-wiki" "$TARGET_PLUGIN/bin/llm-wiki"

mkdir -p "$TARGET_PLUGIN/skills" "$TARGET_SKILL"
# references/ is a symlink into the canonical source. It must never be copied
# over: copying the source references/ onto its own symlink would write into
# the canonical tree. Mirror every other entry, then handle the link itself.
find "$TARGET_SKILL" -mindepth 1 -maxdepth 1 ! -name references -exec rm -rf {} +
for entry in "$SOURCE_SKILL"/* "$SOURCE_SKILL"/.[!.]*; do
  [ -e "$entry" ] || continue
  case "$(basename "$entry")" in
    references) continue ;;
  esac
  cp -R "$entry" "$TARGET_SKILL/"
done

# Recreate the references symlink only when it is missing or wrong. Rewriting a
# correct link every run is what breaks checkouts on platforms where ln -s
# silently produces something other than a symlink (Windows without the
# privilege to create them), turning a good tree into a dirty one.
REFERENCES_LINK="../../../../claude-plugin/skills/wiki-manager/references"
if [ -L "$TARGET_SKILL/references" ] && [ "$(readlink "$TARGET_SKILL/references")" = "$REFERENCES_LINK" ]; then
  :
else
  rm -rf "$TARGET_SKILL/references"
  ln -s "$REFERENCES_LINK" "$TARGET_SKILL/references" 2>/dev/null || true
  if [ ! -L "$TARGET_SKILL/references" ]; then
    rm -rf "$TARGET_SKILL/references"
    cp -R "$SOURCE_SKILL/references" "$TARGET_SKILL/references"
    echo "warning: this platform cannot create symlinks; copied references/ instead." >&2
    echo "         Do not commit that copy. Restore the link with:" >&2
    echo "         git checkout -- $TARGET_SKILL/references" >&2
  fi
fi

# Best-effort OpenCode query preset. It is instruction-only and shares the
# runtime-neutral query contract, but no provider-specific live model gate is
# claimed because OpenCode does not select a model on behalf of the user.
rm -rf "$TARGET_QUERY"
mkdir -p "$TARGET_QUERY"
cat > "$TARGET_QUERY/SKILL.md" <<'EOF'
---
name: wiki-query
description: >
  Fast, read-only, index-first llm-wiki queries for OpenCode and compatible
  instruction-file harnesses.
---

EOF
cat "$QUERY_SOURCE" >> "$TARGET_QUERY/SKILL.md"

python3 - "$TARGET_SKILL" <<'PY'
import sys
from pathlib import Path

target_skill = Path(sys.argv[1])

skill_path = target_skill / "SKILL.md"
text = skill_path.read_text(encoding="utf-8")

frontmatter = """---
name: wiki-manager
description: >
  Manage LLM-compiled wikis in OpenCode: ingest/import, shape/promote Ideas,
  review portfolios, track inventory/datasets, archive, compile/query/lint/audit,
  research/plan, manage sessions, private adapters, personal specialists, and outputs.
  Activates when the user mentions wiki workflows, knowledge-base management,
  ingestion, collection ingestion, import wiki, collect, catalog, curate,
  find all, idea, turn idea into project, portfolio, business ideas, projects, inventory, source queue,
  candidate list, watch list, backlog, dataset, large data, data registry,
  dataset manifest, compilation, querying, linting, audit, research, librarian,
  scan quality, article quality, content review, output drift, provenance,
  archive wiki, archive topic, restore wiki, private adapter, adapter registry, skill-factory,
  checkpoints,
  personal specialist, specialist skill, specialist reviewer, expert lens,
  adapter route, adapter doctor, adapter run, edit an external resource, session capture, capture context, rehydrate,
  resume from session, lessons learned, implementation plan, or uses
  wiki-related shorthand in a repo with .wiki/, ~/wiki/, or a
  configured hub path.
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
        "You manage an LLM-compiled knowledge base. Source documents are ingested into `raw/`, then incrementally compiled into a wiki of interconnected markdown articles. OpenCode is both the compiler and the query engine.\n\n## OpenCode Integration Notes\n\nThis skill is loaded as an instruction file. OpenCode does not have Claude-style `/wiki:*` slash commands or Codex-style `@wiki` invocations. Treat any `/wiki:*` references in this skill and its references as shorthand for the equivalent natural-language request. For example, `/wiki:compile` means the user is asking you to compile the wiki.\n\nOpenCode's built-in tools (`read`, `write`, `edit`, `glob`, `grep`, `bash`, `webfetch`, `websearch`) map directly to the tools this skill requires. Web search requires `OPENCODE_ENABLE_EXA=1` in the environment.\n\n**Permissions**: OpenCode sandboxes file access to the project directory. The wiki hub at `~/wiki/` is external. Add `external_directory` permissions in `opencode.json` to allow access: `{ \"permission\": { \"external_directory\": { \"~/wiki/**\": \"allow\", \"~/.config/llm-wiki/**\": \"allow\" } } }`. If your configured hub uses another absolute path (for example iCloud Drive), add that path too. Alternatively, use `--local` mode to keep everything in `.wiki/` inside the project.\n",
    ),
    (
        "**Dual-linking for Obsidian + Claude.** Cross-references use both `[[wikilink]]` (for Obsidian graph view) and standard markdown `[text](path)` (for Claude navigation) on the same line: `[[slug|Name]] ([Name](../category/slug.md))`. Bidirectional when it makes sense.",
        "**Dual-linking for Obsidian + OpenCode.** Cross-references use both `[[wikilink]]` (for Obsidian graph view) and standard markdown `[text](path)` (for OpenCode navigation) on the same line: `[[slug|Name]] ([Name](../category/slug.md))`. Bidirectional when it makes sense.",
    ),
    (
        "When this skill activates outside of an explicit `/wiki:*` command:",
        "When this skill activates outside of an explicit wiki-related request:",
    ),
    (
        '4. If no relevant content → answer normally, optionally suggest: "This could be added to your wiki with `/wiki:ingest`"',
        '4. If no relevant content → answer normally, optionally suggest: "This could be added to your wiki — just ask me to ingest it."',
    ),
    (
        'Track uncompiled sources by comparing `raw/_index.md` ingestion dates against the last compile date in `_index.md`. If 5+ uncompiled sources exist after an ingestion, suggest: "You have N uncompiled sources. Run `/wiki:compile` to integrate them."',
        'Track uncompiled sources by comparing `raw/_index.md` ingestion dates against the last compile date in `_index.md`. If 5+ uncompiled sources exist after an ingestion, suggest: "You have N uncompiled sources. Ask me to compile them."',
    ),
    (
        'Suggest `/wiki:lint --fix`, which will move contents to the appropriate topic wiki, repair archive registry drift, or quarantine to `inbox/.unknown/` per C11/C12/C16/C17/C19 in `references/linting.md`.',
        'Suggest running the lint --fix workflow, which will move contents to the appropriate topic wiki, repair archive registry drift, or quarantine to `inbox/.unknown/` per C11/C12/C16/C17/C19 in `references/linting.md`.',
    ),
    (
        "Tell the user what's wrong and suggest `/wiki:lint --fix`.",
        "Tell the user what's wrong and suggest running lint with --fix.",
    ),
    (
        "Multiple Claude Code sessions can safely read and write to the same wiki simultaneously. No locks are needed.",
        "Multiple OpenCode sessions can safely read and write to the same wiki simultaneously. No locks are needed.",
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

skill_path.write_text(text, encoding="utf-8", newline="\n")

# references/ is a symlink to claude-plugin/skills/wiki-manager/references and
# is shared verbatim — no per-file replacements needed. Source references use
# runtime-neutral wording ("the agent") so they read correctly under all runtimes.
PY

echo "Synced OpenCode plugin skill from Claude source."
echo "Source: $SOURCE_SKILL"
echo "Target: $TARGET_SKILL"
echo "Best-effort query preset: $TARGET_QUERY"
