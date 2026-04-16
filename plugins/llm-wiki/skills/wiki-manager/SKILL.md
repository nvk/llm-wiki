---
name: wiki-manager
description: >
  LLM-compiled knowledge base manager for Codex. Use it to initialize, ingest,
  compile, query, lint, research, and generate outputs from topic-scoped wikis.
  Activates when the user mentions wiki workflows, knowledge-base management,
  ingestion, compilation, querying, linting, research, or uses /wiki-style
  shorthand in a repo with .wiki/, ~/wiki/, or a configured hub path.
---

# LLM Wiki Manager

You manage an LLM-compiled knowledge base. Source documents are ingested into `raw/`, then incrementally compiled into a wiki of interconnected markdown articles. Codex is both the compiler and the query engine.

## Codex Plugin Notes

Codex plugins package skills, MCP servers, apps, and metadata. They do not register Claude-style custom `/wiki:*` commands. Treat any `/wiki`, `/wiki:*`, or command-flag examples in this skill and its references as shorthand for the same workflow expressed in natural language, or via explicit invocation such as `@llm-wiki` or `@wiki-manager`.

## Hub Path

The hub defaults to `~/wiki/`. If `~/wiki/` exists and is initialized (has `_index.md`), it is used directly — no config file needed. This is the simplest, most reliable path.

To use a different location (e.g., iCloud Drive) when `~/wiki/` is not set up, create `~/.config/llm-wiki/config.json`:

```json
{ "hub_path": "~/Library/Mobile Documents/com~apple~CloudDocs/wiki" }
```

**Resolution**: At the start of every operation, resolve **HUB** by following the protocol in [references/hub-resolution.md](references/hub-resolution.md) — check `~/wiki/` first, then fall back to config. This handles tilde expansion, paths with spaces, and iCloud directory names correctly. All references to `~/wiki/` below mean HUB.

## Wiki Location

**Topic sub-wikis are the default.** HUB is a hub — content lives in `HUB/topics/<name>/`. Each topic gets isolated indexes, sources, and articles. This keeps queries focused and prevents unrelated topics from polluting each other's search space.

Resolution order:

1. `--local` flag → `.wiki/` in current project
2. `--wiki <name>` flag → named wiki from `HUB/wikis.json`
3. Current directory has `.wiki/` → use it
4. Otherwise → HUB (the hub)

When a command targets the hub and the hub has no content, suggest creating a topic sub-wiki instead.

See [references/wiki-structure.md](references/wiki-structure.md) for the complete directory layout and all file format conventions.

## Core Principles

1. **Indexes are a derived cache.** The `.md` files and their YAML frontmatter are the source of truth. `_index.md` files are a cached view rebuilt on read when stale. Always read indexes first for navigation — but before trusting one, stale-check it (file count vs row count). See [references/indexing.md](references/indexing.md) for the Derived Index Protocol.

2. **Raw is immutable.** Once ingested into `raw/`, sources are never modified. They are a record of what was ingested and when. All synthesis happens in `wiki/`.

3. **Articles are synthesized, not copied.** A wiki article draws from multiple sources, contextualizes, and connects to other concepts. Think textbook, not clipboard.

4. **Dual-linking for Obsidian + Codex.** Cross-references use both `[[wikilink]]` (for Obsidian graph view) and standard markdown `[text](path)` (for Codex navigation) on the same line: `[[slug|Name]] ([Name](../category/slug.md))`. Bidirectional when it makes sense.

5. **Frontmatter is structured data.** Every `.md` file has YAML frontmatter with title, summary, tags, dates. This makes the wiki searchable without full-text scans.

6. **Incremental over wholesale.** Compilation processes only new sources by default. Full recompilation is expensive and explicit (`--full`).

7. **Honest gaps.** When answering questions, if the wiki doesn't have the answer, say so. Never hallucinate. Suggest what to ingest to fill the gap.

8. **Multi-wiki awareness.** When querying, answer from the primary wiki first. Then peek at sibling wiki indexes (via `HUB/wikis.json`) for relevant overlap. Flag connections but never merge content across wikis.

## Ambient Behavior

When this skill activates outside of an explicit `@llm-wiki`, `@wiki-manager`, or `/wiki`-style shorthand:

1. Resolve the hub path (see Hub Path section above), then check if `HUB/_index.md` or `.wiki/_index.md` exists
2. Read the master `_index.md` to assess if the wiki might cover the user's question
3. If relevant content exists → read the relevant articles and answer with citations
4. If no relevant content → answer normally, optionally suggest: "This could be added to your wiki; ask `@wiki-manager` to ingest it."
5. When peeking at sibling wikis, only read their `_index.md` — do not read full articles unless the user asks

## Workflows

### Ingestion
See [references/ingestion.md](references/ingestion.md).
Flow: Source (URL/file/text/tweet/inbox) → fetch/read → extract metadata → write to `raw/{type}/` → update indexes → suggest compile if many uncompiled.

### Compilation
See [references/compilation.md](references/compilation.md).
Flow: Survey uncompiled sources → plan articles → classify (concept/topic/reference) → write/update articles with cross-references → update all indexes.

### Query
Flow: Read `_index.md` → identify relevant articles by summary/tag → read articles → follow See Also links → Grep for additional matches → synthesize answer with citations → note gaps → peek sibling wikis. Supports `--resume` to reload context after a session break — reads session files, recent log entries, wiki stats, and last-updated articles to produce a "where you left off" briefing.

### Linting
See [references/linting.md](references/linting.md).
Flow: Check structure → indexes → links → content → coverage → report → optionally auto-fix.

### Search
Flow: Scan indexes for summary/tag matches → Grep full-text → rank results → present.

### Output
Flow: Gather relevant articles → generate artifact (summary/report/slides/etc) → save to `output/` → update indexes.

## Links: File Paths and URLs

Terminal links break when they wrap to a second line. Rules for all wiki operations:

1. **Full absolute paths** — expand `~`, HUB, and all relative segments. Relative paths are not clickable.
2. **Markdown link syntax for URLs** — use `[short text](url)`, never bare long URLs that wrap and break.
3. **No indentation before links** — indentation eats terminal width. Put links flush-left on their own line.
4. **One link per line** — don't embed a long path mid-sentence. Break it out:
   ```
   Saved to:
   /Users/name/wiki/topics/my-topic/output/report-2026-04-08.md
   ```

See `references/research-infrastructure.md` § Agent Prompt Templates for examples. Applies to ingest, compile, research, output, assess.

## Activity Log

Every wiki operation appends to `log.md` in the wiki root. Format: `## [YYYY-MM-DD] operation | Description`. See [references/wiki-structure.md](references/wiki-structure.md) for full format. Never edit or delete existing log entries — append only.

## Confidence Scoring

Wiki articles include a `confidence` field in frontmatter: `high`, `medium`, or `low`.

- **high**: Multiple peer-reviewed sources agree, well-established knowledge
- **medium**: Single source, or sources partially agree, or recent findings not yet replicated
- **low**: Anecdotal, single non-peer-reviewed source, or sources disagree

When answering queries, note confidence levels. When linting, flag `low` confidence articles for review.

## Compilation Nudge

Track uncompiled sources by comparing `raw/_index.md` ingestion dates against the last compile date in `_index.md`. If 5+ uncompiled sources exist after an ingestion, suggest: "You have N uncompiled sources. Ask `@wiki-manager` to compile them."

## Structural Guardian

Automatically run a quick structural check when any of these triggers occur:

### Triggers
- **After any write operation** (ingest, compile, research, output) — verify what was just written
- **When the skill activates** and the wiki hasn't been linted in 7+ days (check "Last lint" in `_index.md`)
- **When content is found in the wrong place** — articles in the global hub instead of a topic sub-wiki
- **When a user mentions wiki problems** — "wiki is broken", "empty", "missing", "wrong"

### Quick Structure Check (lightweight, runs inline — not a full lint)

1. **Hub integrity**: The hub (HUB) should ONLY contain `wikis.json`, `_index.md`, `log.md`, and `topics/`. If `raw/`, `wiki/`, `output/`, `inbox/`, or `config.md` exist at the hub level → **warn, do not delete**. These may hold user data from an older wiki layout. Suggest the `lint --fix` workflow, which will move contents to the appropriate topic wiki or quarantine to `inbox/.unknown/` per C11/C12 in `references/linting.md`.

2. **Index freshness**: For the active topic wiki, compare actual file count in `wiki/concepts/`, `wiki/topics/`, `wiki/references/` against the rows in their `_index.md`. If mismatched → auto-fix by adding missing entries or removing dead ones.

3. **Orphan detection**: Check if any `.md` files exist in wiki directories but are not listed in any `_index.md`. If found → add them to the index.

4. **Missing directories**: Verify all expected subdirectories exist in the topic wiki (`raw/articles/`, `raw/papers/`, etc.). If missing → create them with empty `_index.md`.

5. **wikis.json sync**: Check that all topic sub-wikis under `HUB/topics/` are registered in `wikis.json`. If a directory exists but isn't registered → add it. If registered but directory is missing → remove the entry.

6. **Log existence**: Verify `log.md` exists in the active wiki and at the hub. If missing → create it.

### Behavior

- **Silent when clean** — don't report anything if everything checks out
- **Auto-fix trivial issues** — missing indexes, unregistered wikis, orphan files. Just fix and note in log.
- **Warn on structural problems** — content in wrong place, missing directories, stale indexes. Tell the user what's wrong and suggest the equivalent of `lint --fix`.
- **Never block the user's request** — run the check, fix what you can, report issues, then continue with what the user actually asked for.

## Concurrency

Multiple Codex sessions can safely read and write to the same wiki simultaneously. No locks are needed.

- **Indexes** are derived from the actual files on disk. If two sessions write articles at the same time, the next read rebuilds the index from whatever files exist. Both rebuilds converge to the same correct result.
- **log.md** is append-only with small atomic writes. Concurrent appends are safe.
- **Article/source files** are written independently. Two sessions creating different files never conflict. Two sessions editing the same file is unlikely and handled by last-write-wins (acceptable for a wiki — the content is always rebuildable from raw sources).

See [references/indexing.md](references/indexing.md) for the Derived Index Protocol.

## Session Management

### Research Session Registry

When a `--min-time` research or thesis session is active, the wiki root contains a `.research-session.json` or `.thesis-session.json` file.

**Structural Guardian behavior**:
- If a session file exists with `status: "in_progress"` and `start_time` > 7 days ago → warn: "Stale research session found. Resume or rerun the research workflow, or delete it manually."
- Session files are ephemeral — never included in structural health checks or index counts
- Session files should NOT be committed to git
