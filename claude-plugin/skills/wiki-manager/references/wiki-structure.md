# Wiki Directory Structure

> **Configurable hub path**: The hub location is read from `~/.config/llm-wiki/config.json` (`hub_path` field preferred; `resolved_path` is a legacy fallback). If no config exists, `~/wiki/` is the fallback. Throughout this document, `HUB/` means "the resolved hub path". See [hub-resolution.md](hub-resolution.md) for the full resolution protocol (tilde expansion, space handling, iCloud paths).

## Hub (HUB/)

The hub is lightweight — it has NO content directories. It tracks topic wikis
and may hold user-owned local operational configuration.

```
HUB/                               # resolved from ~/.config/llm-wiki/config.json
├── wikis.json                     # Registry of all topic wikis
├── _index.md                      # Lists topic wikis with stats
├── log.md                         # Global activity log
├── .sessions/                     # Optional harness-session operational memory
├── .skills/                       # Optional personal specialist method library
│   ├── _index.md                  # Derived specialist catalog
│   ├── registry.json              # Per-active-topic specialist allowlists
│   └── <name>/
│       ├── SKILL.md               # Agent Skills-compatible review method
│       └── references/            # Optional Markdown references only
└── topics/                        # Each topic is a full wiki
    ├── dementia/
    ├── quantum-computing/
    ├── .archive/                  # Archived topic wikis, hidden by default
    │   └── old-topic/
    └── ...
```

The hub still has no `raw/`, `wiki/`, `inventory/`, `datasets/`, `output/`,
`inbox/`, `config.md`, `schema.md`, or `.obsidian/`. `.skills/` contains
reusable instructions and allowlists, not evidence or topic content. Its
packages are instruction-only: `SKILL.md` plus optional Markdown under
`references/`. See [specialists.md](specialists.md).

## Topic Sub-Wiki (HUB/topics/<name>/)

All content lives here. Init creates a core structure first, including a
human-owned advisory `schema.md`. Optional layers are created lazily when a
command needs them. This keeps new wikis fast to create and avoids blank
scaffolding for inventory, datasets, and generated sidecars that may never be
used.

```
HUB/topics/<name>/
├── .obsidian/                     # Optional Obsidian vault config
├── _index.md                      # Master index: stats, quick nav, recent changes
├── .librarian/                    # Optional: wiki-only maintenance reports
│   ├── REPORT.md
│   └── scan-results.json
├── .audit/                        # Optional: umbrella audit reports
│   ├── REPORT.md
│   └── scan-results.json
├── config.md                      # Title, scope, conventions
├── schema.md                      # Topic-local vocabulary/conventions
├── log.md                         # Topic-level activity log
├── inbox/                         # Drop zone for this topic
│   └── .processed/
├── inventory/                     # Lazy: durable tracking records (see inventory.md)
│   ├── _index.md
│   ├── items/                     # Physical/digital items, parts, tools, assets
│   │   ├── _index.md
│   │   └── *.md
│   ├── ideas/                     # Proposals shaped before Project commitment
│   │   ├── _index.md
│   │   └── *.md                   # kind: idea
│   ├── candidates/                # Ingest candidates, tasks, questions, watch items
│   │   ├── _index.md
│   │   └── *.md
│   ├── entities/                  # People, orgs, projects, venues, standards bodies
│   │   ├── _index.md
│   │   └── *.md
│   ├── corpora/                   # Source collections, archives, datasets, forums
│   │   ├── _index.md
│   │   └── *.md
│   └── views/                     # Derived chat/list views over inventory
│       ├── _index.md
│       └── *.md
├── datasets/                      # Lazy: dataset manifests for large/external data
│   ├── _index.md
│   └── <dataset-slug>/
│       ├── _index.md
│       ├── MANIFEST.md
│       ├── samples/_index.md      # Lazy: created by dataset sample
│       ├── profiles/_index.md     # Lazy: created by dataset profile
│       └── queries/_index.md      # Lazy: created for query recipes
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

See [inventory.md](inventory.md) for inventory records, [ideas.md](ideas.md) for
the Concept → Idea → Project workflow, [datasets.md](datasets.md) for dataset
manifests, and [projects.md](projects.md) for the full projects architecture.
Files under `inventory/views/` are derived list/table views. They are not
inventory records and should not be treated as authoritative tracking state.
Missing optional roots (`inventory/`, `datasets/`, `.obsidian/`, `.librarian/`,
or `.audit/`) mean the layer has not been used yet. Missing `schema.md` means
an older wiki has not adopted a topic guide; it remains valid, but status/lint should
offer a non-blocking adoption path.

## Local Wiki (--local flag)

Same structure as above but rooted at `<project>/.wiki/` without `wikis.json` or `topics/`.

## Wiki Resolution Order

When a command runs, first resolve the hub path (HUB) from `~/.config/llm-wiki/config.json` (see `hub-resolution.md`). Then resolve which wiki to use:

1. `--local` flag present → `<cwd>/.wiki/`
2. `--wiki <name>` flag present → look up name in `HUB/wikis.json`; resolve `<HUB>`, leading `~`, absolute, and HUB-relative paths, and fall back to `HUB/topics/<name>` when a registry path is stale
3. Current directory has `.wiki/` → use it
4. Otherwise → HUB

## wikis.json Format

```json
{
  "default": "<HUB>",
  "wikis": {
    "hub": { "path": "<HUB>", "description": "Global knowledge base" },
    "<topic>": { "path": "topics/<topic>", "description": "...", "status": "active" },
    "<archived-topic>": {
      "path": "topics/.archive/<archived-topic>",
      "description": "...",
      "status": "archived",
      "archived": "YYYY-MM-DD",
      "archive_reason": "optional"
    }
  },
  "local_wikis": [
    { "path": "/absolute/path/.wiki", "description": "..." }
  ]
}
```

Topic paths inside the shared hub should be relative (`topics/<topic>`) or use
the `<HUB>` token. Avoid storing `/Users/<name>/...` absolute paths for
hub-owned topic wikis; those break when an iCloud wiki is opened from another
Mac with a different home directory.

Archived topic wikis live under `topics/.archive/<slug>` and should keep their
registry entries with `status: archived`. Normal wiki resolution, status,
query, compile, research, output, librarian, refresh, and audit workflows skip
archived entries unless the user explicitly includes archived content. See
[archive.md](archive.md) for lifecycle semantics and restore rules.

## _index.md Format

Every existing wiki-managed directory has an `_index.md`. This is the agent's
primary navigation aid. Optional directories do not need placeholder indexes
before they exist.

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
- Inventory records: N tracked items
- Datasets: N manifests
- Outputs: N generated artifacts
- Archived topics: N (hub index only)
- Last compiled: YYYY-MM-DD
- Last lint: YYYY-MM-DD

## Quick Navigation

- [All Sources](raw/_index.md)
- [Inventory](inventory/_index.md) — include only when `inventory/` exists
- [Datasets](datasets/_index.md) — include only when `datasets/` exists
- [Concepts](wiki/concepts/_index.md)
- [Topics](wiki/topics/_index.md)
- [References](wiki/references/_index.md)
- [Outputs](output/_index.md)
```

## log.md Format

Append-only chronological activity log. Every wiki operation appends an entry. Never edit or delete existing entries during normal workflows. The sole exception is an explicit user-directed privacy retraction with `scripts/llm-wiki retract --remove-from-logs`, which atomically removes complete matching entries while preserving unrelated history. **Otherwise always open for append, never read-modify-write** — this makes concurrent writes safe (lines from multiple sessions interleave without corruption). Format is grep-friendly:

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

Operations: `init`, `ingest`, `ingest-collection`, `compile`, `query`, `lint`, `research`, `output`, `refresh`, `librarian`, `audit`, `plan`, `idea`, `project`, `inventory`, `dataset`, `schema`, `archive`, `retract`, `ll`, `assess`

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

## Topic Guide (`schema.md`) Format

`schema.md` is default for new topic wikis and is human-owned. It is a topic
guide, not a database schema: it captures the local vocabulary that helps
agents avoid taxonomy drift, including entity types, relationship verbs, article
subtypes, source conventions, inventory/dataset boundaries, and adoption notes.

Every runtime's compilation workflow reads a topic's `schema.md` in full before
planning new or updated articles. Its structural guidance can shape cardinality
(for example, consolidate several sources about one mechanism), article
boundaries, topic scope, and named concepts that should remain separate. This
is an operational planning input, not a second lint schema.

The guide cannot redefine deeper global primitives: the `category` vocabulary
stays `concept`/`topic`/`reference`, the physical layout stays `raw/` →
`wiki/concepts|topics|references/`, and the required-frontmatter set stays
fixed. Additional topic fields remain optional to deterministic tooling.
Likewise, prose telling compilation to exclude a raw source does not satisfy C6
coverage: the source remains visible in the uncompiled-source backlog until an
article cites it or the user explicitly re-ingests it into the correct topic.

```markdown
---
title: "Wiki Title Topic Guide"
schema_state: advisory
created: YYYY-MM-DD
updated: YYYY-MM-DD
summary: "Human-owned topic guide for local vocabulary and conventions."
---

# Wiki Title Topic Guide

> This is not a database schema and it does not make existing wiki content invalid.

## State

- `schema_state`: `advisory`

## Entity Types

| Type | Meaning |
|------|---------|
| `concept` | Bounded idea or mechanism. |

## Relationship Verbs

- `cites`
- `supports`
- `contradicts`
- `supersedes`
- `depends-on`
- `implements`

## Source Conventions

[Topic-specific evidence and boundary rules]

## Compile Guidance (optional)

[Topic-specific cardinality, article-boundary, scope, and keep-separate rules.
These rules shape compilation planning but do not redefine global categories,
frontmatter, or raw-source coverage.]
```

Adoption states:

| State | Meaning | Behavior |
|-------|---------|----------|
| `missing` | Older wiki without `schema.md` | Valid; show non-blocking adoption nudge |
| `proposed` | Librarian wrote `output/schema-proposal-*.md` | Human reviews and edits before adoption |
| `advisory` | `schema.md` exists | Follow by default; explain deliberate compile deviations |
| `strict` | Explicit opt-in in `schema.md` | Confirm planned deviations before writing; never auto-rewrite content |

Topic-guide helpers:

- `llm-wiki schema status <wiki-root>` shows whether a wiki has a schema.
- `llm-wiki schema adopt <wiki-root>` writes an advisory starter when missing.
- `llm-wiki schema adopt --dry-run <wiki-root>` previews the starter.
- `llm-wiki schema migrate --apply <wiki-root>` remains as a compatibility alias.
- `llm-wiki lint --fix <wiki-root>` may also create the default topic guide.

## Source File Format (raw/)

```markdown
---
title: "Title"
source: "URL, filepath, MANUAL, or provenance label such as session"
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
compiled-from: sources|conversation|mixed   # optional; defaults to "sources"
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

Each source-backed article's freshness is a composite of four dimensions, each contributing 0-25 points:

| Dimension | What it measures | Computed from |
|-----------|-----------------|---------------|
| **Source freshness** | How old are the raw sources this article was compiled from? | Average days since `ingested:` across all `sources:` entries |
| **Verification recency** | When did a human last confirm accuracy? | Days since `verified:` |
| **Compilation recency** | When was this article last recompiled? | Days since `updated:` |
| **Source chain integrity** | Do all referenced sources still exist? | % of `sources:` entries that resolve to actual files |

Each dimension's decay curve is scaled by the article's `volatility` tier — a hot article's source freshness decays faster than a cold one's. The Lindy Effect applies: cold content that has survived without needing updates is more durable, not less.

Articles with `compiled-from: conversation` have no fetchable raw source chain. For those articles, skip source freshness and source chain integrity, compute verification recency and compilation recency at 0-25 points each, then multiply the 50-point subtotal by 2 so the final score still lands on 0-100. Articles with `compiled-from: mixed` use the standard four-dimension formula because they still carry raw sources.

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
- **Inventory records**: `descriptive-slug.md` (no date — durable tracking state)
- **Dataset manifests**: `datasets/descriptive-slug/MANIFEST.md`
- **Output artifacts**: `{type}-{topic-slug}-{YYYY-MM-DD}.md`
- All filenames: lowercase, hyphens for spaces, no special characters, max 60 chars

## Tag Convention

Tags are lowercase, hyphenated. Prefer specific over general:
- Good: `transformer-architecture`, `self-attention`, `natural-language-processing`
- Bad: `ai`, `ml`, `tech`

Normalize across the wiki — no near-duplicates like `ml` vs `machine-learning`.
