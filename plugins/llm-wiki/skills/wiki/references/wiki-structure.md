# Wiki Directory Structure

> **Configurable hub path**: The hub location is read from `~/.config/llm-wiki/config.json` (`resolved_path` field). If no config exists, `~/wiki/` is the fallback. Throughout this document, `HUB/` means "the resolved hub path". See [hub-resolution.md](hub-resolution.md) for the full resolution protocol (tilde expansion, space handling, iCloud paths).

## Hub (HUB/)

The hub is lightweight — it has NO content directories. It only tracks topic wikis.

```
HUB/                               # resolved from ~/.config/llm-wiki/config.json
├── wikis.json                     # Registry of all topic wikis
├── _index.md                      # Lists topic wikis with stats
├── log.md                         # Global activity log
└── topics/                        # Each topic is a full wiki
    ├── dementia/
    ├── quantum-computing/
    └── ...
```

## Topic Sub-Wiki (HUB/topics/<name>/)

All content lives here. Each topic wiki has the full structure:

```
HUB/topics/<name>/
├── .obsidian/                     # Obsidian vault config
├── _index.md                      # Master index: stats, quick nav, recent changes
├── .librarian/                    # Optional: wiki-only maintenance reports
│   ├── REPORT.md
│   └── scan-results.json
├── .audit/                        # Optional: umbrella audit reports
│   ├── REPORT.md
│   └── scan-results.json
├── config.md                      # Title, scope, conventions
├── log.md                         # Topic-level activity log
├── inbox/                         # Drop zone for this topic
│   └── .processed/
├── raw/                           # Immutable source material
│   ├── _index.md
│   ├── articles/
│   │   ├── _index.md
│   │   └── *.md
│   ├── papers/
│   │   ├── _index.md
│   │   └── *.md
│   ├── repos/
│   │   ├── _index.md
│   │   └── *.md
│   ├── notes/
│   │   ├── _index.md
│   │   └── *.md
│   └── data/
│       ├── _index.md
│       └── *.md
├── wiki/                          # Compiled articles (LLM-maintained)
│   ├── _index.md
│   ├── concepts/
│   │   ├── _index.md
│   │   └── *.md
│   ├── topics/
│   │   ├── _index.md
│   │   └── *.md
│   ├── references/
│   │   ├── _index.md
│   │   └── *.md
│   └── theses/                    # Thesis investigations
│       ├── _index.md
│       └── *.md
└── output/                        # Generated artifacts
    ├── _index.md
    ├── projects/                  # Project folders (see projects.md)
    │   ├── <slug>/
    │   │   ├── WHY.md             # Required: goal + rationale in plain markdown
    │   │   ├── *.md               # Markdown deliverables
    │   │   ├── *.png, *.svg       # Colocated images/diagrams
    │   │   ├── code/              # Optional — prototype scripts
    │   │   └── data/              # Optional — CSVs, JSON exports
    │   └── .archive/              # Archived projects (moved here by /wiki:project archive)
    │       └── <slug>/
    │           └── WHY.md
    └── *.md                       # Loose outputs (backward compatible)
```

See [projects.md](projects.md) for the full projects architecture (lifecycle, multi-membership, explicit `--project <slug>` scoping).

## Local Wiki (--local flag)

Same structure as above but rooted at `<project>/.wiki/` without `wikis.json` or `topics/`.

## Wiki Resolution Order

When a command runs, first resolve the hub path (HUB) from `~/.config/llm-wiki/config.json` (see `hub-resolution.md`). Then resolve which wiki to use:

1. `--local` flag present → `<cwd>/.wiki/`
2. `--wiki <name>` flag present → look up name in `HUB/wikis.json`
3. Current directory has `.wiki/` → use it
4. Otherwise → HUB

## wikis.json Format

```json
{
  "default": "<HUB>",
  "wikis": {
    "hub": { "path": "<HUB>", "description": "Global knowledge base" },
    "<topic>": { "path": "<HUB>/topics/<topic>", "description": "..." }
  },
  "local_wikis": [
    { "path": "/absolute/path/.wiki", "description": "..." }
  ]
}
```

## _index.md Format

Every directory has an `_index.md`. This is the agent's primary navigation aid.

```markdown
# [Directory Name] Index

> [One-line description of what this directory contains]

Last updated: YYYY-MM-DD

## Contents

| File | Summary | Tags | Updated |
|------|---------|------|---------|
| [filename.md](filename.md) | One-sentence summary | tag1, tag2 | YYYY-MM-DD |

## Categories

- **category-name**: file1.md, file2.md

## Recent Changes

- YYYY-MM-DD: Description of change
```

### Master _index.md (root level)

Additionally includes:

```markdown
## Statistics

- Sources: N raw documents
- Articles: N compiled wiki articles
- Outputs: N generated artifacts
- Last compiled: YYYY-MM-DD
- Last lint: YYYY-MM-DD

## Quick Navigation

- [All Sources](raw/_index.md)
- [Concepts](wiki/concepts/_index.md)
- [Topics](wiki/topics/_index.md)
- [References](wiki/references/_index.md)
- [Outputs](output/_index.md)
```

## log.md Format

Append-only chronological activity log. Every wiki operation appends an entry. Never edit or delete existing entries. **Always open for append, never read-modify-write** — this makes concurrent writes safe (lines from multiple sessions interleave without corruption). Format is grep-friendly:

```markdown
# Wiki Activity Log

## [2026-04-04] init | Wiki initialized
## [2026-04-04] ingest | Attention Is All You Need (raw/papers/2026-04-04-attention-is-all-you-need.md)
## [2026-04-04] ingest | Illustrated Transformer (raw/articles/2026-04-04-illustrated-transformer.md)
## [2026-04-04] ingest-collection | bitcoin-bips via git: 389 new, 0 skipped, 389 total candidates
## [2026-04-04] compile | 2 sources → 3 new articles, 1 updated (transformer-architecture, self-attention, sequence-modeling + updated attention-mechanisms)
## [2026-04-04] query | "How does self-attention work?" → answered from 2 articles
## [2026-04-05] lint | 12 checks, 0 critical, 2 warnings, 3 suggestions, 1 auto-fixed
## [2026-04-05] research | "transformer variants" → 5 sources ingested, 4 articles compiled
## [2026-04-05] output | summary on transformer-architecture → output/summary-transformer-architecture-2026-04-05.md
```

Each entry: `## [YYYY-MM-DD] operation | Description`

Operations: `init`, `ingest`, `ingest-collection`, `compile`, `query`, `lint`, `research`, `output`, `refresh`, `librarian`, `audit`, `plan`, `project`, `ll`, `assess`

Useful for: `grep "^## \[" log.md | tail -10` to see recent activity.

## config.md Format

```markdown
---
title: "Wiki Title"
description: "What this wiki is about"
created: YYYY-MM-DD
freshness_threshold: 70
---

# Wiki Configuration

## Scope

[What topics this wiki covers]

## Conventions

[Any wiki-specific conventions beyond defaults]
```

## Source File Format (raw/)

```markdown
---
title: "Title"
source: "URL or filepath or MANUAL"
type: articles|papers|repos|notes|data
ingested: YYYY-MM-DD
tags: [tag1, tag2]
summary: "2-3 sentence summary"
---

# Title

[Full content]
```

### Optional Collection Provenance

Raw files created by `/wiki:ingest-collection` may include additional
frontmatter. These keys are canonical and should not be linted as unknown:

```yaml
collection: "<stable collection slug>"
adapter: git|mediawiki-dump|mediawiki-api
upstream_id: "<repo path, page id, or page title>"
upstream_type: git-file|mediawiki-page
revision: "<commit sha, dump revision id, or timestamp>"
sha: "<blob sha or content hash>"
canonical_url: "<stable upstream URL>"
content_format: markdown|mediawiki|wikitext|text
license: "<detected license or unknown>"
authors: [optional names]
categories: [optional upstream categories]
outlinks: [optional upstream links]
fetched: YYYY-MM-DD
```

Collection manifests live in `raw/repos/` with `type: repos` and
`tags: [collection, collection-manifest, <adapter>]`. Child pages/specs usually
live in `raw/articles/` with `type: articles`. The raw layer is still immutable:
if an upstream page changes, ingest the new revision as a new raw source instead
of overwriting the old one.

## Wiki Article Format (wiki/)

```markdown
---
title: "Article Title"
category: concept|topic|reference
sources: [raw/type/file1.md, raw/type/file2.md]
created: YYYY-MM-DD
updated: YYYY-MM-DD
tags: [tag1, tag2]
aliases: [alternate names for Obsidian discovery]
confidence: high|medium|low
volatility: hot|warm|cold
verified: YYYY-MM-DD
summary: "2-3 sentence summary for index"
---

# Article Title

> [One-paragraph abstract]

## [Sections as appropriate]

[Synthesized content — explain, contextualize, connect. NOT copy-paste.]

When referencing another wiki article inline, use dual-link format:
[[article-slug|Display Name]] ([Display Name](../category/article-slug.md))

This ensures both Obsidian (reads [[wikilink]]) and the agent (follows relative path) can navigate.

## See Also

- [[related-slug|Related Article]] ([Related Article](../category/related-slug.md)) — relationship note

## Sources

- [Source Title](../../raw/type/file.md) — what this source contributed
```

## Source Reference Resolution

The `sources:` field is a path list, not a bag of slugs. Maintenance workflows
that follow provenance (`librarian`, `lint`, `audit`, `refresh`, and project
staleness checks) must resolve source references with this protocol:

1. Parse `sources:` as structured YAML when possible. If using a line-based
   fallback, preserve the complete scalar after `- ` through the end of the line
   and strip only matching wrapping quotes. Never split source entries on
   whitespace.
2. Resolve exact paths first:
   - `raw/...`, `wiki/...`, and `output/...` are relative to the wiki root.
   - `../...` and `./...` are relative to the file that owns the `sources:`
     field.
   - Absolute paths are allowed only when they point inside the resolved wiki
     root; report outside paths as external/unmanaged.
3. If exact path resolution fails, use slug fallback for legacy or human-entered
   references. Normalize both the requested value and every candidate raw file
   stem by lowercasing, replacing whitespace/underscores with hyphens, removing
   non-alphanumeric characters except hyphens, collapsing repeated hyphens, and
   trimming leading/trailing hyphens. Also compare candidate stems after removing
   a leading `YYYY-MM-DD-` date prefix. A single match resolves; zero or
   multiple matches must be reported as unresolved or ambiguous.
4. Do not rename raw files during resolution. Raw immutability means old or
   imported filenames may contain spaces, title case, or upstream identifiers.
   Canonicalize future ingests, but preserve existing raw file paths.
5. When writing new `sources:` entries for filenames with spaces or punctuation,
   prefer block-list YAML and quote the path:
   `- "raw/articles/2026-01-03-Title Cased Source.md"`.
6. When linking to a raw file whose path contains spaces in article body
   markdown, use angle-bracket link destinations:
   `[Source Title](<../../raw/articles/2026-01-03-Title Cased Source.md>)`.

## Volatility Classification

Wiki articles carry a `volatility` field that controls how quickly their freshness score decays. The `verified` field records when a human last confirmed the article's conclusions are still accurate.

| Tier | Decay rate | When to use | Examples |
|------|-----------|-------------|----------|
| `hot` | Fast | Fast-moving sources: product specs, pricing, current events, competitive landscape | NVIDIA Spark specs, election results, API changelog |
| `warm` | Moderate | Quarterly-to-annual cadence: best practices, framework comparisons, market analysis | Testing patterns, CLI UX patterns, market positioning |
| `cold` | Slow | Foundational concepts, historical events, mathematical proofs, stable reference | TCP/IP fundamentals, Lindy Effect, cryptographic algorithms |

Default is `warm`. The compilation agent sets volatility based on source characteristics: news/trends sources suggest `hot`, foundational/historical sources suggest `cold`. Authors can override.

### Freshness Score (0-100)

Each article's freshness is a composite of four dimensions, each contributing 0-25 points:

| Dimension | What it measures | Computed from |
|-----------|-----------------|---------------|
| **Source freshness** | How old are the raw sources this article was compiled from? | Average days since `ingested:` across all `sources:` entries |
| **Verification recency** | When did a human last confirm accuracy? | Days since `verified:` |
| **Compilation recency** | When was this article last recompiled? | Days since `updated:` |
| **Source chain integrity** | Do all referenced sources still exist? | % of `sources:` entries that resolve to actual files |

Each dimension's decay curve is scaled by the article's `volatility` tier — a hot article's source freshness decays faster than a cold one's. The Lindy Effect applies: cold content that has survived without needing updates is more durable, not less.

The freshness threshold is set per wiki in `config.md` (default: 70). Articles scoring below the threshold are flagged by lint. There are no hardcoded day cutoffs — the composite score naturally flags the right articles at the right time based on their volatility and the actual state of their sources.

## Dual-Link Convention

All cross-references between wiki articles use BOTH link formats on the same line:

```
[[target-slug|Display Text]] ([Display Text](../category/target-slug.md))
```

- **Obsidian** reads the `[[wikilink]]` for its graph view, backlinks panel, and navigation
- **The agent** follows the standard markdown `(relative/path.md)` link
- Both coexist on one line so neither system misses the connection

For inline mentions in article body text, use the same pattern:
```
The [[transformer-architecture|Transformer]] ([Transformer](../concepts/transformer-architecture.md)) uses self-attention...
```

## Obsidian Compatibility

The wiki is designed to be opened as an Obsidian vault. On `/wiki init`, a `.obsidian/` config directory is created with minimal settings. Key compatibility notes:

- YAML frontmatter `tags` field is read natively by Obsidian
- `aliases` in frontmatter lets Obsidian find articles by alternate names
- `_index.md` files appear as regular notes in Obsidian (this is fine)
- The `inbox/` folder works as a natural Obsidian inbox
- Graph view shows connections via `[[wikilinks]]`

## Output Artifact Format (output/)

```markdown
---
title: "Output Title"
type: summary|report|study-guide|slides|timeline|glossary|comparison
sources: [wiki/category/article.md, ...]
generated: YYYY-MM-DD
---

[Content in the appropriate format for the type]
```

## File Naming

- **Raw sources**: `YYYY-MM-DD-descriptive-slug.md` (date prefix for chronological order)
- **Wiki articles**: `descriptive-slug.md` (no date — living documents)
- **Output artifacts**: `{type}-{topic-slug}-{YYYY-MM-DD}.md`
- All filenames: lowercase, hyphens for spaces, no special characters, max 60 chars

## Tag Convention

Tags are lowercase, hyphenated. Prefer specific over general:
- Good: `transformer-architecture`, `self-attention`, `natural-language-processing`
- Bad: `ai`, `ml`, `tech`

Normalize across the wiki — no near-duplicates like `ml` vs `machine-learning`.
