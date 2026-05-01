---
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

# LLM Wiki Manager

You manage an LLM-compiled knowledge base. Source documents are ingested into `raw/`, then incrementally compiled into a wiki of interconnected markdown articles. Codex is both the compiler and the query engine.

## Codex Plugin Notes

Codex plugins package skills, MCP servers, apps, and metadata. They do not register Claude-style custom `/wiki:*` commands. Treat any `/wiki`, `/wiki:*`, or command-flag examples in this skill and its references as shorthand for the same workflow expressed in natural language, or via explicit `@wiki` invocation.

## Hub Path

**Resolution**: At the start of every operation, resolve **HUB** by reading `~/.config/llm-wiki/config.json` first. If it has `resolved_path`, use that value directly. If it has only `hub_path`, expand the leading `~` only (not tildes in `com~apple~CloudDocs`), set HUB, and write `resolved_path` back. If no config file exists, try `~/wiki/_index.md` as a fallback. See [references/hub-resolution.md](references/hub-resolution.md) for the full protocol.

The config file looks like:

```json
{
  "hub_path": "~/Library/Mobile Documents/com~apple~CloudDocs/wiki",
  "resolved_path": "/Users/jane/Library/Mobile Documents/com~apple~CloudDocs/wiki"
}
```

If no config exists and `~/wiki/` has `_index.md`, that works too. But config is checked first — in sandboxed environments `~/wiki/` may not be accessible. All references to `~/wiki/` below mean HUB.

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

9. **Chunk large writes.** Never create files longer than ~200 lines in a single Write call — the API stream idles during large generations, causing timeout errors. Write the skeleton (frontmatter + headers + first section) first, then use sequential Edit calls to append remaining sections. For plans, articles, and raw notes: write one section per tool call.

## Ambient Behavior

When this skill activates outside of an explicit `@wiki` invocation or `/wiki`-style shorthand:

1. Resolve the hub path (see Hub Path section above), then check if `HUB/_index.md` or `.wiki/_index.md` exists
2. Read the master `_index.md` to assess if the wiki might cover the user's question
3. If relevant content exists → read the relevant articles and answer with citations
4. If no relevant content → answer normally, optionally suggest: "This could be added to your wiki; ask `@wiki` to ingest it."
5. When peeking at sibling wikis, only read their `_index.md` — do not read full articles unless the user asks

When giving any boot, resume, or "where you left off" briefing, start with the
active wiki identity: `<wiki-name> booted from <wiki-root-path>`. Prefer the
`config.md` title; for local `.wiki/` projects, fall back to the parent
directory name; for `HUB/topics/<slug>/`, fall back to the slug. Include this
line even when there is nothing in flight to resume.

If the user asks whether they can trust a wiki artifact, requests an audit,
mentions provenance or drift, or asks for content verification beyond a normal
query, use the Audit workflow instead of treating it as plain Q&A.

## Workflows

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

## Operational Rules

- Use absolute file paths in saved-output messages and markdown links for URLs.
- Append to `log.md` for every wiki write operation; never rewrite old log entries.
- Keep large writes chunked into multiple edits rather than one long generation.
- Read `_index.md` files before broader scans, and treat indexes as derived data.
- Use article `confidence` fields when answering and flag weak sourcing when seen.
- If structure or placement looks wrong, use the `lint --fix` workflow from
  `references/linting.md` instead of inventing a one-off repair path.

