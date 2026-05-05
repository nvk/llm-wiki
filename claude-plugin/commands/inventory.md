---
description: "Track wiki-adjacent things the user cares about: ingest candidates, entities, corpora, open questions, tasks, and other durable inventory records."
argument-hint: "list [--kind <kind>] [--status <status>] | add <kind> \"<title>\" [--priority p0-p4] [--source <path-or-url>] | show <slug-or-path> | update <path> | scan-outputs [--dry-run] | migrate-output <output-path> [--kind <kind>] [--dry-run|--apply] [--wiki <name>] [--local]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*), Bash(mkdir:*)
---

## Your task

**Resolve the wiki.** Do NOT broadly search the filesystem — follow these steps:
1. Read `$HOME/.config/llm-wiki/config.json`. If it has `resolved_path` → HUB = that value, skip to step 3. If only `hub_path`, expand leading `~` only (not tildes in `com~apple~CloudDocs`), set HUB, write `resolved_path` back, skip to step 3.
2. If no config → read `$HOME/wiki/_index.md`. If it exists → HUB = `$HOME/wiki`. If nothing found, ask the user where to create the wiki.
3. **Wiki location** (first match): `--local` → `.wiki/` in CWD; `--wiki <name>` → `HUB/wikis.json` lookup; CWD has `.wiki/` → use it; else → HUB.
4. Read `<wiki>/_index.md` to verify. If missing → stop with "No wiki found. Run `/wiki init` first."

After resolving the wiki, read the inventory reference at `skills/wiki-manager/references/inventory.md`, then run the requested subcommand.

Inventory records are durable tracking objects, not compiled articles and not raw sources. Use them for ingest candidates, important entities, corpora to watch, open questions, recurring tasks, or "things we want to keep inventory of." They live under `inventory/` and can point at raw/wiki/output files without moving them.

### Parse $ARGUMENTS

Subcommands:

- **list**: List inventory records, optionally filtered by `--kind`, `--status`, or `--priority`.
- **add <kind> "<title>"**: Create a new inventory record in the canonical subdirectory for `kind`.
- **show <slug-or-path>**: Read one inventory record.
- **update <path>**: Edit one inventory record based on the user's instructions.
- **scan-outputs [--dry-run]**: Look for output artifacts that look like inventory but still live in `output/`.
- **migrate-output <output-path> [--kind <kind>] [--dry-run|--apply]**: Convert one legacy output artifact into an inventory record. Default is **dry-run**. `--apply` is required to write a new inventory file.

Kinds:
`ingest-candidate`, `entity`, `corpus`, `question`, `task`, `artifact`, `watch`.

Statuses:
`proposed`, `active`, `blocked`, `ingested`, `superseded`, `archived`.

Priorities:
`p0`, `p1`, `p2`, `p3`, `p4`, where `p0` is highest.

### Ensure Structure

Before any write:

1. Ensure these directories exist, each with `_index.md`:
   - `inventory/`
   - `inventory/candidates/`
   - `inventory/entities/`
   - `inventory/corpora/`
   - `inventory/views/`
2. If any are missing, create only the missing directory and empty index files. This is a structural migration path for older wikis; it does not migrate existing content.

### Add

1. Slugify the title using normal wiki filename rules.
2. Pick the target directory:
   - `ingest-candidate`, `question`, `task`, `artifact`, `watch` → `inventory/candidates/`
   - `entity` → `inventory/entities/`
   - `corpus` → `inventory/corpora/`
3. Write a markdown record with frontmatter per `references/inventory.md`.
4. Include the user's source/path/URL in `sources:` when provided.
5. Append to `log.md`:
   `## [YYYY-MM-DD] inventory | added <kind> <slug>`
6. Rebuild `inventory/_index.md` and the containing subdirectory `_index.md`.

### List

1. Read `inventory/_index.md` first.
2. If filters are present, search inventory records by frontmatter.
3. Present a compact table with title, kind, status, priority, next action, and updated date.

### Scan Outputs

This is the migration discovery path. It must not write inventory files.

1. Scan `output/**/*.md`, excluding `_index.md` and `output/projects/*/WHY.md`.
2. Flag artifacts that look like durable tracking material:
   - filenames containing `queue`, `backlog`, `inventory`, `candidate`, `watch`, `sources`, `corpus`, or `dataset`
   - frontmatter titles containing those same terms
   - bodies with repeated tables of sources, priorities, statuses, URLs, or next actions
3. For each candidate, suggest a `migrate-output` command and likely kind.
4. Report: "No files were migrated. Run `inventory migrate-output <path> --apply` to create inventory records."

### Migrate Output

Default mode is dry-run. This creates a migration plan only:

1. Read the output artifact.
2. Infer one or more inventory records:
   - queue rows → `ingest-candidate`
   - named people/org/projects → `entity`
   - corpus/dataset/source collection descriptions → `corpus`
3. Preserve the original output path in frontmatter as `origin: output/...`.
4. Do **not** move or delete the source output. Inventory migration is additive.
5. In dry-run, show the proposed filenames and frontmatter only.
6. With `--apply`, write the proposed inventory records, update indexes, and append to `log.md`:
   `## [YYYY-MM-DD] inventory | migrated <output-path> -> N inventory records`

### Report

Always include:

- Inventory root path
- Records created/updated, if any
- Migration candidates found, if any
- Reminder when dry-run mode was used
