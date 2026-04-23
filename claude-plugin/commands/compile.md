---
description: "Compile raw sources into wiki articles. Synthesizes, cross-references, and organizes knowledge."
argument-hint: "[--full] [--source <path>] [--topic <name>] [--wiki <name>] [--local]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*), Bash(mv:*), Bash(mkdir:*)
---

## Your task

**Resolve the wiki.** Do NOT search the filesystem or read reference files — follow these steps:
1. Read `$HOME/.config/llm-wiki/config.json`. If it has `resolved_path` → HUB = that value, skip to step 3. If only `hub_path`, expand leading `~` only (not tildes in `com~apple~CloudDocs`), set HUB, write `resolved_path` back, skip to step 3.
2. If no config → read `$HOME/wiki/_index.md`. If it exists → HUB = `$HOME/wiki`. If nothing found, ask the user where to create the wiki.
3. **Wiki location** (first match): `--local` → `.wiki/` in CWD; `--wiki <name>` → `HUB/wikis.json` lookup; CWD has `.wiki/` → use it; else → HUB.
4. Read `<wiki>/_index.md` to verify. If missing → stop with "No wiki found. Run `/wiki init` first."

Read the compilation protocol at `skills/wiki-manager/references/compilation.md` and the indexing protocol at `skills/wiki-manager/references/indexing.md`. Then compile raw sources into wiki articles.

### Parse $ARGUMENTS

- **--full**: Recompile everything from scratch
- **--source <path>**: Compile only this specific source file
- **--topic <name>**: Create or update a specific topic article

### Compilation Process

0. **Placement pre-check** (C13 + C11 from `references/linting.md`): Before surveying, walk `raw/` and for each `.md` file read its frontmatter. Rewrite any legacy keys/values using the C13 alias table. Then compare the file's `type` field to its actual directory — if it's misplaced (e.g., `type: papers` but sitting in `raw/notes/`, or loose at the wiki root), `mv` it to the canonical path, creating the destination directory if needed. This is the same rule lint uses, run inline because you're already reading every frontmatter. It heals both user miscategorization and stale layouts from older wiki versions — there is no separate migration pass. On slug collisions at the destination, skip and warn. Do this before step 1 so the survey sees canonical state. Does not touch `output/projects/` — that's compile step 7's territory.

1. **Survey**: Read `raw/_index.md` to see all sources. Read `wiki/_index.md` to see existing articles. For incremental mode, identify sources ingested after the "Last compiled" date in master `_index.md`.

2. If no uncompiled sources found (incremental mode), report: "All sources are already compiled. Use `--full` to recompile everything."

3. **Read sources**: Read each uncompiled source in full. Extract key concepts, facts, relationships.

4. **Plan**: For each concept found:
   - Check existing wiki articles (via `wiki/_index.md` summaries and tags)
   - Decide: create new article, update existing, or mention within another article
   - Classify new articles as concept, topic, or reference

5. **Write/Update articles**: Follow the protocol in `references/compilation.md` and core principle #9 (chunked writes):
   - New articles: Write frontmatter + abstract first, then Edit to append body, See Also, Sources
   - Updated articles: use Edit to integrate new information, update frontmatter dates
   - Every article must link to at least one other via See Also

6. **Bidirectional links**: For every See Also link A→B, ensure B→A exists

7. **Update indexes (best-effort)**: Update `wiki/concepts/_index.md`, `wiki/topics/_index.md`, `wiki/references/_index.md`, `wiki/_index.md`, and master `_index.md` (article count, "Last compiled" date, Recent Changes). If `output/projects/` exists, rebuild `output/_index.md` as a projects-aware listing: scan each `output/projects/*/WHY.md` for its first `#` heading (title) and first non-heading paragraph (goal), list them as a table, then list any remaining loose outputs in `output/` below. If any index update is skipped or interrupted, no data is lost — the next read operation will detect the stale index and rebuild it from file frontmatter. See `references/indexing.md` Derived Index Protocol and `references/compilation.md` Step 7.

8. **Log**: Append to `log.md`: `## [YYYY-MM-DD] compile | N sources → X new articles, Y updated (list slugs)`

9. **Report**:
   - Sources processed: N
   - New articles created: list with paths
   - Existing articles updated: list with paths
   - New cross-references added: count
   - Suggest: `/wiki:lint` to verify consistency
