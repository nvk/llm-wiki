---
description: "Ingest source material into the wiki. Accepts URLs, file paths, freeform text, or processes the inbox. Supports tweets via Grok MCP."
argument-hint: "<url|filepath|\"text\"> [--type articles|papers|repos|notes|data] [--title \"Title\"] [--inbox] [--keep] [--wiki <name>] [--local]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*), Bash(mv:*), Bash(basename:*), Bash(file:*), WebFetch, WebSearch
---

## Your task

First, check if a wiki exists by trying to read `~/wiki/_index.md` (global) and `.wiki/_index.md` (local).


Read the ingestion protocol at `skills/wiki-manager/references/ingestion.md` and the structure spec at `skills/wiki-manager/references/wiki-structure.md`. Then ingest source material.

### Resolve wiki location

1. `--local` flag → `.wiki/`
2. `--wiki <name>` flag → look up in `~/wiki/wikis.json`
3. Current directory has `.wiki/` → use it
4. Otherwise → `~/wiki/` (hub — triggers auto-classification, see below)

If the resolved wiki does not exist, stop: "No wiki found. Run `/wiki init` first."

### Auto-classify to topic wiki (when resolved to hub)

When the wiki resolves to `~/wiki/` (the hub) — meaning no `--wiki`, `--local`, or local `.wiki/` — do NOT write directly to the hub. Instead, classify the content into a topic wiki:

1. Read `~/wiki/wikis.json` to get the list of topic wikis
2. For each topic wiki, read its `config.md` to understand its scope and description
3. After fetching/reading the source content (title, URL, summary), compare it against each topic wiki's scope
4. **If a topic wiki matches:** Suggest it to the user: *"This looks like it belongs in `<wiki-name>` (<description>). Route there? (y/n/other)"*
   - If the user confirms, use that wiki as the target
   - If the user says "other", ask which wiki or whether to create a new one
5. **If no topic wiki matches:** Suggest a new topic wiki: *"No existing wiki matches this content. Create a new one? Suggested name: `<suggested-name>`"*
   - If the user confirms, run the init flow for that wiki, then continue ingestion into it
   - If the user provides a different name, use that instead
6. **If `--inbox` is set (batch mode):** Classify each item individually. Group items by suggested wiki and present the classification as a summary table before processing:
   ```
   Inbox classification:
   | # | Title | Suggested wiki | Confidence |
   |---|-------|---------------|------------|
   | 1 | Attention Is All You Need | ai-basics | high |
   | 2 | Agent Governance Toolkit | ai-security | high |
   | 3 | Kubernetes RBAC Guide | (new: cloud-infra) | medium |
   
   Proceed with this routing? (y/edit/abort)
   ```
   - "y" processes all items as classified
   - "edit" lets the user reassign individual items
   - "abort" cancels

This step is skipped when `--wiki` or `--local` is explicitly provided.

### Parse $ARGUMENTS

- **--inbox**: Process all files in the wiki's `inbox/` directory
- **--keep**: When processing inbox, keep originals (move to .processed/ instead of deleting)
- **--type**: Force source type (articles, papers, repos, notes, data). Default: auto-detect.
- **--title**: Override extracted title
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

1. Detect tweet URLs (`x.com/*/status/*` or `twitter.com/*/status/*`):
   - Try Grok MCP tool to fetch tweet content
   - Fallback to WebFetch if Grok unavailable
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
3. Update `raw/{type}/_index.md` — add row to Contents table
4. Update `raw/_index.md` — add row
5. Update master `_index.md` — increment source count, add to Recent Changes
6. Append to `log.md`: `## [YYYY-MM-DD] ingest | Title (raw/type/slug.md)`
7. Report: what was ingested, where saved, detected tags
8. Check uncompiled source count. If 5+, suggest `/wiki:compile`
