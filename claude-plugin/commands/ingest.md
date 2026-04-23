---
description: "Ingest source material into the wiki. Accepts URLs, file paths, freeform text, or processes the inbox. Supports tweets via Grok MCP."
argument-hint: "<url|filepath|\"text\"> [--type articles|papers|repos|notes|data] [--title \"Title\"] [--inbox] [--keep] [--wiki <name>] [--local] [--auto-classify] [--new-topic <name>] [--project <slug>]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*), Bash(mv:*), Bash(mkdir:*), Bash(basename:*), Bash(file:*), WebFetch, WebSearch
---

## Your task

**Resolve the wiki.** Do NOT search the filesystem or read reference files — follow these steps:
1. Read `$HOME/wiki/_index.md`. If it exists → HUB = `$HOME/wiki`. Skip to step 3.
2. If not → read `$HOME/.config/llm-wiki/config.json`. Use `resolved_path` as HUB. If only `hub_path` exists, expand leading `~` only (not tildes in `com~apple~CloudDocs`), set HUB, write `resolved_path` back. If no config → HUB = `$HOME/wiki`.
3. **Wiki location** (first match): `--local` → `.wiki/` in CWD; `--wiki <name>` → `HUB/wikis.json` lookup; CWD has `.wiki/` → use it; else → HUB.
4. Read `<wiki>/_index.md` to verify. If missing and `--new-topic <name>` is set → create the topic wiki (see below). If missing and no `--new-topic` → stop with "No wiki found. Use `--new-topic <name>` to create one, or run `/wiki init` first."

Read the ingestion protocol at `skills/wiki-manager/references/ingestion.md` and the structure spec at `skills/wiki-manager/references/wiki-structure.md`. Then ingest source material.

### `--new-topic` branch

When `--new-topic` is set, override the standard resolution:
1. Derive a slug from the topic name: lowercase, hyphens, no special chars, max 40 chars
2. If HUB doesn't exist, create it (wikis.json + _index.md + log.md + topics/)
3. Create the new topic wiki at `HUB/topics/<slug>/` following the full init protocol (directory structure, .obsidian/, empty _index.md files, config.md, log.md)
4. Register in `HUB/wikis.json` and update hub `_index.md`
5. Target this new wiki for ingestion

### `--project <slug>` flag

**--project <slug>**: Tag the ingested source with `project: <slug>` frontmatter. The raw file still lands in the normal `raw/<type>/` location (sources are shared across projects by design). The project tagging propagates later when sources are compiled into wiki articles. See `references/projects.md`.

If `--project <slug>` is set, verify the project exists at `<wiki-root>/output/projects/<slug>/WHY.md`. If not, fail early: `Project "<slug>" does not exist. Create it first with /wiki:project new <slug> "goal".`

There is no ambient project focus — pass `--project` explicitly when you want project scope. The focus-session mechanism (`.wiki-session.json`) was removed in the v0.2 projects simplification; see `references/projects.md` § "Focus" for the rationale.

### Parse $ARGUMENTS

- **--new-topic <name>**: Create a new topic wiki and ingest the source into it. Works from any directory. Derives the wiki slug from the name (e.g., "knives" → `knives`, "machine learning" → `machine-learning`).
- **--inbox**: Process all files in the wiki's `inbox/` directory
- **--keep**: When processing inbox, keep originals (move to .processed/ instead of deleting)
- **--type**: Force source type (articles, papers, repos, notes, data). Default: auto-detect.
- **--title**: Override extracted title
- **--auto-classify**: For single items, classify into the best-matching topic wiki instead of requiring `--wiki`. Always active for `--inbox` when no `--wiki` is set.
- **Source**: Everything else — URL (starts with http), file path (contains / or .), or quoted freeform text

### If --inbox

Follow the inbox processing protocol from `references/ingestion.md`:

1. Scan `inbox/` for files (exclude `.processed/` and hidden files)
2. If empty, report: "Inbox is empty. Drop files into `<wiki-path>/inbox/` and run again."
3. Process each file according to its type
4. Move processed files to `inbox/.processed/` (unless `--keep`, then copy)
5. Update all indexes
6. Report summary
7. If 5+ items processed, suggest compilation

### If URL source

1. Detect X.com/Twitter URLs (`x.com/*/status/*` or `twitter.com/*/status/*`):
   - **Grok MCP** (preferred): Check for `mcp__grok__*` tools. If available, use to fetch tweet. See [ask-grok-mcp](https://github.com/nvk/ask-grok-mcp).
   - **FxTwitter**: Rewrite URL → `https://api.fxtwitter.com/user/status/ID`, WebFetch for JSON.
   - **VxTwitter**: Rewrite URL → `https://api.vxtwitter.com/user/status/ID`, WebFetch for JSON.
   - **Direct WebFetch**: Last resort, often blocked by login wall.
   - Full fallback chain details in `references/ingestion.md`.
   - Type: notes (unless overridden)

2. Detect GitHub URLs (`github.com/*`):
   - Use WebFetch with repo-specific extraction prompt
   - Type: repos (unless overridden)

3. All other URLs:
   - Use WebFetch to extract article content
   - Auto-detect type from URL patterns (arxiv → papers, etc.)

### If file path source

1. Read the file
2. Auto-detect type from extension and content
3. For structured data (.json, .csv), describe schema + sample

### If quoted text source

1. Use the text as-is
2. Type: notes (unless overridden)
3. Derive title from first sentence if --title not provided

### Topic Wiki Routing (when no --wiki specified)

When the wiki resolved to the hub (HUB) and no `--wiki` flag was provided, route content to the right topic wiki AFTER fetching the source content (title, summary, tags are now known).

**Skip this step entirely if** `--wiki` or `--local` was explicitly provided.

#### Single item (no --inbox)

If `--auto-classify` is set, or the user didn't specify `--wiki`:

1. Read `HUB/wikis.json` to list topic wikis
2. For each topic wiki with a `config.md`, read the description/scope (first 5 lines is enough)
3. Match the source's title + summary + tags against wiki scopes
4. Present a simple numbered choice:
   ```
   Route to:
   1) ai-security — "AI security, agent safety, prompt injection..."
   2) geo — "GEO & AI Search Optimization..."
   3) New wiki
   4) Skip (leave in hub inbox for later)
   ```
5. User picks a number. Use that wiki as target for the rest of the flow.

If only one topic wiki exists, still ask (don't assume). If zero topic wikis exist, ask whether to create one or ingest to hub raw/.

#### Batch mode (--inbox)

When `--inbox` is set and no `--wiki` was provided, classify items as a batch:

1. Scan inbox, fetch/read each item to get title + summary
2. For each item, match against topic wiki scopes
3. Present a classification table:
   ```
   Inbox routing:
   | # | Title | → Wiki | Match |
   |---|-------|--------|-------|
   | 1 | Attention Is All You Need | ai-basics | strong |
   | 2 | Agent Auth IETF Draft | ai-security | strong |
   | 3 | K8s RBAC Guide | (new: cloud-infra) | weak |
   | 4 | Random cooking blog | (skip) | none |
   ```
4. User confirms: `y` (process all), `edit` (reassign items), `abort`
5. Process items grouped by target wiki — all ai-security items together, etc.
6. Items marked "skip" stay in inbox untouched
7. Items routed to a "new" wiki trigger the init flow first, then ingest

**Performance note**: Fetch all items first (parallel if possible), classify in one pass, then process. Don't fetch-classify-ingest one at a time — that's fragile if interrupted mid-batch.

### For all sources

1. Generate slug: `YYYY-MM-DD-descriptive-slug.md`
2. Write source file to `raw/{type}/` with proper frontmatter:
   ```
   ---
   title: "Title"
   source: "URL or filepath or MANUAL"
   type: articles|papers|repos|notes|data
   ingested: YYYY-MM-DD
   tags: [auto-generated relevant tags]
   summary: "2-3 sentence summary"
   ---
   ```
3. Update `raw/{type}/_index.md`, `raw/_index.md`, and master `_index.md` (best-effort — if skipped or interrupted, the next read will rebuild from file frontmatter. See `references/indexing.md` Derived Index Protocol.)
4. Append to `log.md`: `## [YYYY-MM-DD] ingest | Title (raw/type/slug.md)`
7. Report: what was ingested, where saved, detected tags
8. Check uncompiled source count. If 5+, suggest `/wiki:compile`
