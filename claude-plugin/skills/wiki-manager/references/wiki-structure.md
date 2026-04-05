# Wiki Directory Structure

## Global Wiki (default)

```
~/wiki/
├── wikis.json                     # Coordination file — tracks all wikis
├── _index.md                      # Master index: stats, quick nav, recent changes
├── config.md                      # Title, scope, conventions
├── inbox/                         # Drop zone — dump files here, then /wiki:ingest --inbox
│   └── .processed/                # Processed items moved here
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
│   └── references/
│       ├── _index.md
│       └── *.md
├── output/                        # Generated artifacts
│   ├── _index.md
│   └── *.md
└── topics/                        # Sub-wikis by topic
    └── <topic-name>/              # Each is a full wiki structure
        ├── _index.md
        ├── config.md
        ├── inbox/
        ├── raw/
        ├── wiki/
        └── output/
```

## Local Wiki (--local flag)

Same structure as above but rooted at `<project>/.wiki/` without `wikis.json` or `topics/`.

## Wiki Resolution Order

When a command runs, resolve which wiki to use:

1. `--local` flag present → `<cwd>/.wiki/`
2. `--wiki <name>` flag present → look up name in `~/wiki/wikis.json`
3. Current directory has `.wiki/` → use it
4. Otherwise → `~/wiki/`

## wikis.json Format

```json
{
  "default": "~/wiki",
  "wikis": {
    "main": { "path": "~/wiki", "description": "Global knowledge base" },
    "<topic>": { "path": "~/wiki/topics/<topic>", "description": "..." }
  },
  "local_wikis": [
    { "path": "/absolute/path/.wiki", "description": "..." }
  ]
}
```

## _index.md Format

Every directory has an `_index.md`. This is Claude's primary navigation aid.

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

## config.md Format

```markdown
---
title: "Wiki Title"
description: "What this wiki is about"
created: YYYY-MM-DD
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
summary: "2-3 sentence summary for index"
---

# Article Title

> [One-paragraph abstract]

## [Sections as appropriate]

[Synthesized content — explain, contextualize, connect. NOT copy-paste.]

When referencing another wiki article inline, use dual-link format:
[[article-slug|Display Name]] ([Display Name](../category/article-slug.md))

This ensures both Obsidian (reads [[wikilink]]) and Claude (follows relative path) can navigate.

## See Also

- [[related-slug|Related Article]] ([Related Article](../category/related-slug.md)) — relationship note

## Sources

- [Source Title](../../raw/type/file.md) — what this source contributed
```

## Dual-Link Convention

All cross-references between wiki articles use BOTH link formats on the same line:

```
[[target-slug|Display Text]] ([Display Text](../category/target-slug.md))
```

- **Obsidian** reads the `[[wikilink]]` for its graph view, backlinks panel, and navigation
- **Claude** follows the standard markdown `(relative/path.md)` link
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
