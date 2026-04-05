---
name: wiki-manager
description: >
  LLM-compiled knowledge base manager. Activates when user works with wiki
  directories, mentions knowledge base management, asks knowledge questions
  in a project with a wiki, wants to ingest/compile/query/lint knowledge,
  or uses /wiki commands. Also activates when user says "wiki", "knowledge base",
  "ingest", "compile wiki", "add to wiki", "search wiki", or asks a factual
  question in a directory containing .wiki/ or when ~/wiki/ exists.
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

# LLM Wiki Manager

You manage an LLM-compiled knowledge base. Source documents are ingested into `raw/`, then incrementally compiled into a wiki of interconnected markdown articles. Claude Code is both the compiler and the query engine — no Obsidian, no external tools.

## Wiki Location

**Global by default** at `~/wiki/`. Resolution order:

1. `--local` flag → `.wiki/` in current project
2. `--wiki <name>` flag → named wiki from `~/wiki/wikis.json`
3. Current directory has `.wiki/` → use it
4. Otherwise → `~/wiki/`

See [references/wiki-structure.md](references/wiki-structure.md) for the complete directory layout and all file format conventions.

## Core Principles

1. **Indexes are navigation.** Always read `_index.md` files first. They contain summaries, tags, and file lists. Never scan directories blindly. Keep indexes current — they are the backbone.

2. **Raw is immutable.** Once ingested into `raw/`, sources are never modified. They are a record of what was ingested and when. All synthesis happens in `wiki/`.

3. **Articles are synthesized, not copied.** A wiki article draws from multiple sources, contextualizes, and connects to other concepts. Think textbook, not clipboard.

4. **Dual-linking for Obsidian + Claude.** Cross-references use both `[[wikilink]]` (for Obsidian graph view) and standard markdown `[text](path)` (for Claude navigation) on the same line: `[[slug|Name]] ([Name](../category/slug.md))`. Bidirectional when it makes sense.

5. **Frontmatter is structured data.** Every `.md` file has YAML frontmatter with title, summary, tags, dates. This makes the wiki searchable without full-text scans.

6. **Incremental over wholesale.** Compilation processes only new sources by default. Full recompilation is expensive and explicit (`--full`).

7. **Honest gaps.** When answering questions, if the wiki doesn't have the answer, say so. Never hallucinate. Suggest what to ingest to fill the gap.

8. **Multi-wiki awareness.** When querying, answer from the primary wiki first. Then peek at sibling wiki indexes (via `~/wiki/wikis.json`) for relevant overlap. Flag connections but never merge content across wikis.

## Ambient Behavior

When this skill activates outside of an explicit `/wiki:*` command:

1. Check if `~/wiki/_index.md` or `.wiki/_index.md` exists
2. Read the master `_index.md` to assess if the wiki might cover the user's question
3. If relevant content exists → read the relevant articles and answer with citations
4. If no relevant content → answer normally, optionally suggest: "This could be added to your wiki with `/wiki:ingest`"
5. When peeking at sibling wikis, only read their `_index.md` — do not read full articles unless the user asks

## Workflows

### Ingestion
See [references/ingestion.md](references/ingestion.md).
Flow: Source (URL/file/text/tweet/inbox) → fetch/read → extract metadata → write to `raw/{type}/` → update indexes → suggest compile if many uncompiled.

### Compilation
See [references/compilation.md](references/compilation.md).
Flow: Survey uncompiled sources → plan articles → classify (concept/topic/reference) → write/update articles with cross-references → update all indexes.

### Query
Flow: Read `_index.md` → identify relevant articles by summary/tag → read articles → follow See Also links → Grep for additional matches → synthesize answer with citations → note gaps → peek sibling wikis.

### Linting
See [references/linting.md](references/linting.md).
Flow: Check structure → indexes → links → content → coverage → report → optionally auto-fix.

### Search
Flow: Scan indexes for summary/tag matches → Grep full-text → rank results → present.

### Output
Flow: Gather relevant articles → generate artifact (summary/report/slides/etc) → save to `output/` → update indexes.

## Compilation Nudge

Track uncompiled sources by comparing `raw/_index.md` ingestion dates against the last compile date in `_index.md`. If 5+ uncompiled sources exist after an ingestion, suggest: "You have N uncompiled sources. Run `/wiki:compile` to integrate them."
