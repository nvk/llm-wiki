---
description: "Search the wiki for content by keyword, tag, or category."
argument-hint: "<query> [--tag <tag>] [--category concepts|topics|references] [--raw] [--wiki <name>] [--local]"
allowed-tools: Read, Glob, Grep, Bash(ls:*)
---

## Your task

First, check if a wiki exists by trying to read `~/wiki/_index.md` (global) and `.wiki/_index.md` (local).

Search the wiki for content matching $ARGUMENTS.

### Resolve wiki location

1. `--local` → `.wiki/`
2. `--wiki <name>` → look up in `~/wiki/wikis.json`
3. Current directory has `.wiki/` → use it
4. Otherwise → `~/wiki/`

If wiki does not exist, stop: "No wiki found. Run `/wiki init` first."

### Parse $ARGUMENTS

- **query**: The search term(s) — everything that is not a flag
- **--tag <tag>**: Filter to articles with this tag in frontmatter
- **--category <cat>**: Search only in concepts, topics, or references
- **--raw**: Search raw sources in addition to wiki articles

### Search Strategy

1. **Index scan**: Read the relevant `_index.md` files. Check summaries and tags for matches. This is the fast path.
   - If `--category` specified, only read that category's index
   - Otherwise read all category indexes under `wiki/`

2. **Full-text search**: Use Grep to search file contents in `wiki/` for the query terms.
   - If `--raw`, also search `raw/`

3. **Tag search**: If `--tag` specified, use Grep to find files with matching tags in YAML frontmatter: `tags:.*<tag>`.

4. **Rank results**: Present ordered by relevance:
   - Title match > summary match > body match
   - Multiple term matches > single term match
   - More recent > older

### Output Format

```
## Search Results for "<query>"

Found N results:

### Wiki Articles
1. **[Title](path)** — summary — tags: tag1, tag2
2. **[Title](path)** — summary — tags: tag1

### Raw Sources (if --raw or if no wiki results found)
1. **[Title](path)** — summary — type: articles
```

If no results found, suggest:
- Alternative search terms
- Broader/narrower tags
- Running `/wiki:ingest` to add relevant sources
