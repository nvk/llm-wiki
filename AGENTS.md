# LLM Wiki — Agent Instructions

> This is an "idea file" in the spirit of [Karpathy's LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f). Paste it into any LLM agent (OpenAI Codex, Claude Code, OpenCode, Gemini Code Assist, or similar) and it will build and manage a wiki for you. The agent customizes the specifics; this file communicates the system.

## What This Is

An LLM-compiled knowledge base. You (the LLM agent) are both the compiler and the query engine. Raw source documents are ingested, then incrementally compiled into a wiki of interconnected markdown articles. The human rarely edits the wiki directly — that's your domain.

**The metaphor**: raw sources are source code, you are the compiler, the wiki is the executable.

## Architecture

### Hub (~/wiki/)

The hub is lightweight — NO content, just a registry.

```
~/wiki/
├── wikis.json          # Registry of all topic wikis
├── _index.md           # Lists topic wikis with stats
├── log.md              # Global activity log
└── topics/
    ├── nutrition/      # Each topic is a full, isolated wiki
    ├── robotics/
    └── ...
```

### Topic Wiki (~/wiki/topics/<name>/)

All content lives here. One topic per wiki. Isolated indexes, focused queries.

```
~/wiki/topics/<name>/
├── .obsidian/                     # Obsidian vault config (optional)
├── _index.md                      # Master index: stats, navigation, recent changes
├── config.md                      # Title, scope, conventions
├── log.md                         # Activity log for this topic
├── inbox/                         # Drop zone — user dumps files here
│   └── .processed/
├── raw/                           # Immutable source material
│   ├── _index.md
│   ├── articles/*.md
│   ├── papers/*.md
│   ├── repos/*.md
│   ├── notes/*.md
│   └── data/*.md
├── wiki/                          # Compiled articles (LLM-maintained)
│   ├── _index.md
│   ├── concepts/*.md              # Bounded ideas
│   ├── topics/*.md                # Broad themes
│   └── references/*.md            # Curated collections
└── output/                        # Generated artifacts
    ├── _index.md
    └── *.md
```

### Local Wiki (.wiki/)

Same structure as a topic wiki but at `<project>/.wiki/`. Add `.wiki/` to `.gitignore`.

## Core Principles

1. **One topic, one wiki.** Never mix unrelated topics. The hub is just a registry.
2. **Indexes are navigation.** Every directory has `_index.md` with a contents table. Read indexes first, never scan blindly. Keep them current.
3. **Raw is immutable.** Once ingested, sources are never modified. All synthesis happens in `wiki/`.
4. **Articles are synthesized, not copied.** Draw from multiple sources, contextualize, connect. Think textbook, not clipboard.
5. **Dual-linking.** Every cross-reference uses both formats on the same line: `[[slug|Name]] ([Name](../category/slug.md))`. Obsidian reads the wikilink, the agent reads the markdown link, GitHub renders it. Not locked into any tool.
6. **Incremental by default.** Only compile new sources unless explicitly asked for full recompile.
7. **Honest gaps.** If the wiki doesn't have the answer, say so. Suggest what to ingest.
8. **Multi-wiki peek.** When querying, answer from the target wiki, then peek at sibling wiki `_index.md` files for overlap.
9. **Confidence scoring.** Articles get `confidence: high|medium|low` in frontmatter based on source quality.
10. **Activity log.** Append every operation to `log.md`. Format: `## [YYYY-MM-DD] operation | Description`. Never edit existing entries.

## File Formats

### _index.md (every directory)

```markdown
# [Directory Name] Index

> [One-line description]

Last updated: YYYY-MM-DD

## Contents

| File | Summary | Tags | Updated |
|------|---------|------|---------|
| [file.md](file.md) | One-sentence summary | tag1, tag2 | YYYY-MM-DD |

## Categories

- **category**: file1.md, file2.md

## Recent Changes

- YYYY-MM-DD: Description
```

Master `_index.md` additionally has Statistics and Quick Navigation sections.

### Raw Source (raw/)

```yaml
---
title: "Title"
source: "URL or filepath or MANUAL"
type: articles|papers|repos|notes|data
ingested: YYYY-MM-DD
tags: [tag1, tag2]
summary: "2-3 sentence summary"
---
```

### Wiki Article (wiki/)

```yaml
---
title: "Article Title"
category: concept|topic|reference
sources: [raw/type/file1.md, raw/type/file2.md]
created: YYYY-MM-DD
updated: YYYY-MM-DD
tags: [tag1, tag2]
aliases: [alternate names]
confidence: high|medium|low
summary: "2-3 sentence summary"
---
```

Body includes abstract, sections, `## See Also` (dual-links, bidirectional), `## Sources` (links to raw/).

### wikis.json

```json
{
  "default": "~/wiki",
  "wikis": {
    "hub": { "path": "~/wiki", "description": "Hub" },
    "<name>": { "path": "~/wiki/topics/<name>", "description": "..." }
  },
  "local_wikis": []
}
```

### log.md

```
## [YYYY-MM-DD] operation | Description
```

Operations: `init`, `ingest`, `compile`, `query`, `lint`, `research`, `output`, `assess`

## Operations

### Init

Create a topic wiki. Always require a topic name. If the hub doesn't exist, create it first (just wikis.json + _index.md + log.md + topics/). Create the full topic wiki structure, empty _index.md files, config.md, log.md, and optionally .obsidian/ vault config.

### Ingest

Convert external material into a raw source file.

- **URLs**: Fetch content, extract title/author/date/text, write to `raw/articles/` or `raw/papers/`
- **Files**: Read directly, preserve formatting
- **Text**: User provides quoted text, write to `raw/notes/`
- **Inbox**: Scan `inbox/` for dumped files, process each by type, move to `inbox/.processed/`

Auto-detect type: arxiv/scholar → papers, github → repos, .csv/.json → data, everything else → articles.

Slug: `YYYY-MM-DD-descriptive-slug.md`. Update all indexes after each ingestion. If 5+ uncompiled sources, suggest compilation.

### Compile

Transform raw sources into wiki articles. Incremental by default (only new sources).

1. Survey: read indexes, identify uncompiled sources
2. Extract: key concepts, facts, relationships from each source
3. Map: which concepts need new articles vs updates to existing
4. Classify: concept (bounded idea), topic (broad theme), reference (curated list)
5. Write: synthesized articles with dual-links, frontmatter, confidence scores, aliases
6. Bidirectional links: if A links to B, ensure B links to A
7. Update all indexes

### Query

Answer questions from wiki content only. Three depths:

- **Quick**: Read indexes only. Fastest.
- **Standard** (default): Read relevant articles + full-text search. Follow See Also links.
- **Deep**: Read everything, search raw sources, peek sibling wikis.

Always cite sources. Note confidence levels. Identify gaps. Never use training data — only wiki content.

### Research

Automated pipeline: search → ingest → compile. Launch parallel agents.

**Standard (5 agents)**: Academic, Technical, Applied, News/Trends, Contrarian

**Deep (8 agents)**: Adds Historical, Adjacent fields, Data/Stats

**Retardmax (10 agents)**: Adds 2 Rabbit Hole agents that chase links from search results. Skip planning phase. Lower quality threshold — ingest aggressively, compile fast. Default 15 sources. Lint later.

Each agent: run multiple searches, fetch full content, evaluate quality (1-5), return ranked source list. Deduplicate across agents. Compile all ingested sources. Report gaps and suggest follow-up research.

### Lint

Health checks with auto-fix capability.

**Checks**: structure integrity, frontmatter validity, index consistency, link integrity, tag hygiene, coverage, deep fact-checking (optional).

**Auto-fix** (`--fix`): missing indexes, orphan files, dead index entries, statistics mismatch, missing bidirectional links, empty frontmatter fields.

### Search

Find content by keyword, tag, or category. Scan indexes first (fast), then full-text search.

### Output

Generate artifacts from wiki content: summary, report, study-guide, slides, timeline, glossary, comparison.

**Retardmax mode**: Read ALL articles, generate immediately without planning structure. Ship rough, iterate later.

Save to `output/`. Update indexes.

### Assess

Compare a local repo against wiki research + market.

1. **Repo scan** (3 parallel agents): structure, features, docs
2. **Wiki scan**: knowledge map from indexes and articles
3. **Gap analysis**: alignment, research gaps (repo does it, wiki doesn't), opportunities (wiki knows it, repo doesn't), neither covers
4. **Market scan** (3-5 parallel agents): competitors, best practices, emerging trends

Output: comparison report with feature matrix, competitive landscape, and recommended actions (specific research and build suggestions).

## Structural Guardian

Auto-run lightweight checks after write operations:

1. Hub should only have wikis.json, _index.md, log.md, topics/. Delete anything else.
2. Index freshness: file counts match index rows. Auto-fix mismatches.
3. Orphan detection: files not in any index → add them.
4. Missing directories → create with empty _index.md.
5. wikis.json sync: all topic dirs registered, no ghost entries.

Silent when clean. Auto-fix trivial issues. Warn on structural problems. Never block the user.

## File Naming

- Raw sources: `YYYY-MM-DD-descriptive-slug.md`
- Wiki articles: `descriptive-slug.md` (no date — living documents)
- Output artifacts: `{type}-{topic-slug}-{YYYY-MM-DD}.md`
- All lowercase, hyphens, no special chars, max 60 chars

## Tag Convention

Lowercase, hyphenated. Specific over general (`transformer-architecture` not `ai`). Normalize — no near-duplicates.

## Obsidian Compatibility

Each topic wiki can be opened as an Obsidian vault. The `.obsidian/` config is created on init with sane defaults. Dual-links power the graph view. Aliases enable search by alternate names. Tags are natively read. The hub has NO `.obsidian/` to avoid nested vault confusion.

## Platform-Specific Notes

This AGENTS.md works with any LLM agent that can read/write files and search the web. Adapt tool names as needed:

| Capability | Claude Code | OpenAI Codex | Generic |
|-----------|------------|-------------|---------|
| Read file | `Read` | `file_read` | read the file |
| Write file | `Write` | `file_write` | write the file |
| Edit file | `Edit` | `file_edit` | edit the file |
| Search files | `Grep` | `shell(grep)` | search file contents |
| Find files | `Glob` | `shell(find)` | find files by pattern |
| Web search | `WebSearch` | `browser` | search the web |
| Fetch URL | `WebFetch` | `browser` | fetch URL content |
| Run command | `Bash` | `shell` | run shell command |
| Subagents | `Agent` | parallel tasks | spawn parallel work |
