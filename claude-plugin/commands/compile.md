---
description: "Compile raw sources into wiki articles. Synthesizes, cross-references, and organizes knowledge."
argument-hint: "[--full] [--source <path>] [--topic <name>] [--wiki <name>] [--local]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*)
---

## Your task

First, resolve **HUB** by following the protocol in `references/hub-resolution.md` (read config, expand leading `~` only, quote paths with spaces). Then check if a wiki exists by trying to read `HUB/_index.md` (global hub) and `.wiki/_index.md` (local).


Read the compilation protocol at `skills/wiki-manager/references/compilation.md` and the indexing protocol at `skills/wiki-manager/references/indexing.md`. Then compile raw sources into wiki articles.

### Resolve wiki location

1. `--local` → `.wiki/`
2. `--wiki <name>` → look up in `HUB/wikis.json`
3. Current directory has `.wiki/` → use it
4. Otherwise → HUB

If wiki does not exist, stop: "No wiki found. Run `/wiki init` first."

### Parse $ARGUMENTS

- **--full**: Recompile everything from scratch
- **--source <path>**: Compile only this specific source file
- **--topic <name>**: Create or update a specific topic article

### Compilation Process

1. **Survey**: Read `raw/_index.md` to see all sources. Read `wiki/_index.md` to see existing articles. For incremental mode, identify sources ingested after the "Last compiled" date in master `_index.md`.

2. If no uncompiled sources found (incremental mode), report: "All sources are already compiled. Use `--full` to recompile everything."

3. **Read sources**: Read each uncompiled source in full. Extract key concepts, facts, relationships.

4. **Plan**: For each concept found:
   - Check existing wiki articles (via `wiki/_index.md` summaries and tags)
   - Decide: create new article, update existing, or mention within another article
   - Classify new articles as concept, topic, or reference

5. **Write/Update articles**: Follow the protocol in `references/compilation.md`:
   - New articles: full frontmatter, abstract, body, See Also, Sources
   - Updated articles: use Edit to integrate new information, update frontmatter dates
   - Every article must link to at least one other via See Also

6. **Bidirectional links**: For every See Also link A→B, ensure B→A exists

7. **Update all indexes**:
   - `wiki/concepts/_index.md`
   - `wiki/topics/_index.md`
   - `wiki/references/_index.md`
   - `wiki/_index.md`
   - Master `_index.md` — update article count, set "Last compiled" to today, add to Recent Changes

8. **Log**: Append to `log.md`: `## [YYYY-MM-DD] compile | N sources → X new articles, Y updated (list slugs)`

9. **Report**:
   - Sources processed: N
   - New articles created: list with paths
   - Existing articles updated: list with paths
   - New cross-references added: count
   - Suggest: `/wiki:lint` to verify consistency
