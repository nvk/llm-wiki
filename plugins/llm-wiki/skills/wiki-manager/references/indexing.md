# Indexing Protocol

## Purpose

Index files (`_index.md`) are the agent's navigation system. Instead of scanning hundreds of files, the agent reads a single index to find what it needs. This is the key efficiency mechanism.

## The 3-Hop Strategy

When answering a query or finding content:

1. **Hop 1**: Read master `_index.md` → get overview, identify which section is relevant
2. **Hop 2**: Read `wiki/{category}/_index.md` → scan summaries and tags for matches
3. **Hop 3**: Read only the matched article files

This means the agent typically reads 2-3 small index files + 3-8 full articles, rather than scanning dozens of files.

## Derived Index Protocol

**Indexes are a cache, not a source of truth.** The `.md` files and their YAML frontmatter are the source of truth. Indexes are rebuilt on read when stale. This makes the wiki concurrent-safe — multiple sessions can write simultaneously without locks.

### Stale Detection

Before using any `_index.md`, check staleness:

1. Count `.md` files in the directory (excluding `_index.md`)
2. Count rows in the `_index.md` contents table
3. If counts differ → index is stale → rebuild inline before proceeding

### Rebuild Inline

When an index is stale:

1. List all `.md` files in the directory (excluding `_index.md`)
2. Read each file's YAML frontmatter (title, summary, tags, updated)
3. Regenerate the `_index.md` contents table from frontmatter
4. Recalculate statistics (source count, article count, etc.)
5. Write the new `_index.md`
6. Continue with the original operation

### Write Operations (ingest, compile, research)

- Write the article/source file with correct frontmatter — this is the source of truth
- Index updates are **best-effort** — update if convenient, but if skipped or if a concurrent session overwrites, no data is lost
- The next read will detect staleness and rebuild

### Read Operations (query, status, lint)

- Always stale-check before trusting the index
- If stale, rebuild first, then proceed
- This adds a small overhead on first read after writes, but guarantees accuracy

### Why This Works for Concurrency

- Two sessions writing articles simultaneously: both write files, neither corrupts the other
- Index may be momentarily stale or one rebuild may overwrite another's rebuild — but since both rebuild from the same source files on disk, the result converges to the same correct state
- `log.md` is append-only with small atomic writes — already safe
- No locks needed, no stale lock cleanup, no coordination between sessions

## When to Update Indexes (Best-Effort)

Write operations SHOULD update indexes when convenient:
- A file is added to the directory
- A file is removed from the directory
- A file's frontmatter (title, summary, tags) changes
- Statistics change (after compilation, after lint)

But these updates are optional. If skipped (e.g., due to a crash or concurrent write), the next read operation will detect the stale index and rebuild it automatically.

## Index Update Procedure

### Adding a file

1. Read the current `_index.md`
2. Add a new row to the Contents table: `| [filename.md](filename.md) | Summary | tags | YYYY-MM-DD |`
3. If the file's tags introduce a new category, add it to the Categories section
4. Add entry to Recent Changes: `- YYYY-MM-DD: Added filename.md (brief note)`
5. Update "Last updated" date

### Removing a file

1. Read the current `_index.md`
2. Remove the row from Contents table
3. Remove from Categories if it was the only file with that category
4. Add removal entry to Recent Changes
5. Update "Last updated" date

### Master Index Statistics

The root `_index.md` statistics are derived from actual file counts, not manual tracking:
- Sources: count .md files in `raw/` subdirectories (excluding `_index.md`)
- Articles: count .md files in `wiki/` subdirectories (excluding `_index.md`)
- Outputs: count .md files in `output/` (excluding `_index.md`)

## Cross-Wiki Index Peek

When peeking at sibling wikis for overlap:
1. Read `HUB/wikis.json` to get the list of all wikis
2. For each sibling wiki, read ONLY its `_index.md` (not full articles)
3. Check if any summaries or tags match the current query
4. If overlap found, note it in the response — never read full articles from sibling wikis unless explicitly asked
