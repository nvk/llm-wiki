---
description: "LLM wiki knowledge base — initialize, show status, or list wikis. Subcommands: ingest, compile, query, lint, search, output."
argument-hint: "[init [name] [--topic] [--local]] [--wiki <name>]"
allowed-tools: Read, Write, Edit, Glob, Bash(ls:*), Bash(wc:*), Bash(mkdir:*), Bash(date:*)
---

## Your task

First, check if a wiki exists by trying to read `~/wiki/_index.md` (global) and `.wiki/_index.md` (local).


You are the llm-wiki knowledge base manager. Read the skill at `skills/wiki-manager/SKILL.md` and structure reference at `skills/wiki-manager/references/wiki-structure.md` for full conventions.

Resolve which wiki to use:
1. If `--local` flag → `.wiki/` in current directory
2. If `--wiki <name>` flag → look up in `~/wiki/wikis.json`
3. If current directory has `.wiki/` → use it
4. Otherwise → `~/wiki/`

---

### If $ARGUMENTS contains "init"

Initialize a new wiki. Parse arguments:
- `init` → create global wiki at `~/wiki/`
- `init --local` → create local wiki at `.wiki/`
- `init <name> --topic` → create sub-wiki at `~/wiki/topics/<name>/`

**Steps:**

1. Create the full directory structure per `references/wiki-structure.md`:
   - `inbox/`, `inbox/.processed/`
   - `raw/`, `raw/articles/`, `raw/papers/`, `raw/repos/`, `raw/notes/`, `raw/data/`
   - `wiki/`, `wiki/concepts/`, `wiki/topics/`, `wiki/references/`
   - `output/`
   - For global wiki only: `topics/`

2. Create `.obsidian/` directory with minimal vault config:
   - `.obsidian/app.json`:
     ```json
     {
       "showFrontmatter": true,
       "alwaysUpdateLinks": true,
       "newLinkFormat": "relative",
       "useMarkdownLinks": false
     }
     ```
   - `.obsidian/appearance.json`:
     ```json
     {
       "accentColor": ""
     }
     ```
   - `.obsidian/graph.json`:
     ```json
     {
       "collapse-filter": false,
       "search": "",
       "showTags": true,
       "showAttachments": false,
       "showOrphans": true,
       "collapse-color-groups": false,
       "collapse-display": false,
       "showArrow": true,
       "textFadeMultiplier": 0,
       "nodeSizeMultiplier": 1,
       "lineSizeMultiplier": 1
     }
     ```
   This makes the wiki immediately openable as an Obsidian vault with sane defaults.

3. Create empty `_index.md` in every directory following the format in `references/wiki-structure.md`. Use today's date. Set all counts to 0.

3. Ask the user: "What is this wiki about?" Use their answer to create `config.md` with title, description, scope, and today's date.

4. For global wiki: create `wikis.json` with the wiki registered. For topic sub-wikis: update existing `~/wiki/wikis.json` to add the new entry. For local wikis: update `~/wiki/wikis.json` `local_wikis` array (create wikis.json first if needed).

5. Report what was created and list available commands:
   - `/wiki:ingest <url|file|text>` — add source material
   - `/wiki:ingest --inbox` — process files dropped in inbox/
   - `/wiki:compile` — compile sources into wiki articles
   - `/wiki:query <question>` — ask questions against the wiki
   - `/wiki:search <query>` — find content
   - `/wiki:lint` — health check
   - `/wiki:output <type>` — generate artifacts

---

### If no "init" argument and a wiki exists

Show wiki status:

1. Read the resolved wiki's `_index.md` for statistics and recent changes
2. Read `config.md` for title and description
3. Count actual files for accuracy:
   - Raw sources: count .md files in `raw/` subdirectories (excluding _index.md)
   - Wiki articles: count .md files in `wiki/` subdirectories (excluding _index.md)
   - Inbox items: count files in `inbox/` (excluding .processed/)
4. Show:
   - Wiki title and description
   - Location (path)
   - Source count / article count / output count
   - Inbox items pending (if any)
   - Last compiled / last lint dates
   - Last 5 recent changes
5. If `~/wiki/wikis.json` exists, list all known wikis with their descriptions
6. List available subcommands

---

### If no wiki exists and no "init" argument

Tell the user:

> No wiki found. Create one with:
> - `/wiki init` — global wiki at ~/wiki/
> - `/wiki init --local` — project-local wiki at .wiki/
> - `/wiki init ml --topic` — topic sub-wiki at ~/wiki/topics/ml/
