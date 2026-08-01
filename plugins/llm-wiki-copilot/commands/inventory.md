---
description: "Track wiki-adjacent things the user cares about: items, ingest candidates, entities, corpora, open questions, tasks, and other durable inventory records."
argument-hint: "list [--kind <kind>] [--status <status>] [--priority p0-p4] [--view summary|actions|items|records|sources] [--limit N] [--format table|list] | add <kind> \"<title>\" [--priority p0-p4] [--source <path-or-url>] | show <slug-or-path> | update <path> | save-view \"<name>\" [filters] | scan-outputs [--dry-run] | migrate-output <output-path> [--kind <kind>] [--dry-run|--apply] [--include-archived] [--wiki <name>] [--local]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*), Bash(mkdir:*)
---

## Your task

**Resolve the wiki.** Do NOT broadly search the filesystem — follow these steps:
1. Read `$HOME/.config/llm-wiki/config.json`. If it has `hub_path`, expand leading `~` only (not tildes in `com~apple~CloudDocs`) and prefer that path; use `resolved_path` only as a fallback cache when the expanded `hub_path` is unavailable and `resolved_path` is initialized. If config has only `resolved_path`, use it. If the configured path can be statted but reading `wikis.json` or listing `topics/` fails with `Operation not permitted`, stop and ask the user to grant Full Disk Access/iCloud Drive access to the launcher; do not fall back to `~/wiki` or `resolved_path`. Do not write machine-specific `resolved_path` into shared configs.
2. If no config → read `$HOME/wiki/_index.md`. If it exists → HUB = `$HOME/wiki`. If nothing found, ask the user where to create the wiki.
3. **Wiki location** (first match): `--local` → `.wiki/` in CWD; `--wiki <name>` → `HUB/wikis.json` lookup with portable path resolution (`<HUB>`, `~`, absolute, or HUB-relative); if the registry path is stale, fall back to `HUB/topics/<name>`; CWD has `.wiki/` → use it; else → HUB.
4. Read `<wiki>/_index.md` to verify. If missing → stop with "No wiki found. Run `/wiki init` first."

Archive rule: inventory commands operate on active topic wikis by default. If a
named target is archived, stop and ask the user to restore it or rerun with
`--include-archived`. When explicitly included, list/update records only inside
that archived topic path and label the result as archived. Do not let archived
inventory records from archived topics appear in default cross-wiki summaries.

After resolving the wiki, read the inventory reference at `skills/wiki-manager/references/inventory.md`, then run the requested subcommand.

Inventory records are durable tracking objects, not compiled articles and not raw sources. Use them for physical or digital items, ingest candidates, important entities, corpora to watch, open questions, recurring tasks, or "things we want to keep inventory of." They live under `inventory/` and can point at raw/wiki/output files without moving them.

Be opinionated. Before writing or migrating records, tell the user whether
inventory is the right layer:

- Good fit: durable state with priority/status/next action, a physical/digital
  item to own/use/compare, a source/corpus to evaluate later, an entity/watch
  item, or a follow-up that should survive the chat session.
- Too small: one-off source to ingest now, a factual question, or a note with no
  future action. Route to ingest, query, or raw notes instead.
- Too big: hundreds of row-like items, datasets, message archives, snapshots, or
  collections. Create one corpus inventory record plus a dataset manifest or
  collection ingest, not one inventory record per row.
- Out of scope: authoritative source text (`raw/`), synthesized knowledge
  (`wiki/`), generated deliverables (`output/`), project goals (`WHY.md`), or
  secrets/private operational data.

For bigger pivots, show a sample table of 1-3 proposed records and the
recommendation before asking to apply. Default to dry-run for migrations and
bulk conversions.

### Parse $ARGUMENTS

Subcommands:

- **list**: List inventory records, optionally filtered by `--kind`, `--status`, or `--priority`.
- **add <kind> "<title>"**: Create a new inventory record in the canonical subdirectory for `kind`.
- **show <slug-or-path>**: Read one inventory record.
- **update <path>**: Edit one inventory record based on the user's instructions.
- **save-view "<name>" [filters]**: Save a derived table/list under `inventory/views/`.
- **scan-outputs [--dry-run]**: Look for output artifacts that look like inventory but still live in `output/`.
- **migrate-output <output-path> [--kind <kind>] [--dry-run|--apply]**: Convert one legacy output artifact into an inventory record. Default is **dry-run**. `--apply` is required to write a new inventory file.

Kinds:
`item`, `ingest-candidate`, `entity`, `corpus`, `question`, `task`, `artifact`, `watch`.

Statuses:
`proposed`, `active`, `blocked`, `ingested`, `superseded`, `archived`.

Priorities:
`p0`, `p1`, `p2`, `p3`, `p4`, where `p0` is highest.

Archive flag:
`--include-archived` explicitly allows the selected wiki itself to be archived.
This is separate from inventory record `status: archived`.

### Ensure Structure

Inventory structure is lazy. Do not create it during read-only operations, and
do not populate empty category folders until a command needs them.

Before a write:

1. Ensure `inventory/` exists with `_index.md`.
2. Ensure only the target subdirectory exists with `_index.md`:
   - `add item` → `inventory/items/`
   - `add entity` → `inventory/entities/`
   - `add corpus` → `inventory/corpora/`
   - `add ingest-candidate`, `add question`, `add task`, `add artifact`, or `add watch` → `inventory/candidates/`
   - `save-view` → `inventory/views/`
3. If a wiki has a partially existing inventory layer, create missing indexes
   only for directories that already exist or that the current write needs. Do
   not create all empty inventory subdirectories as a side effect.

### Add

1. Slugify the title using normal wiki filename rules.
2. Pick the target directory:
   - `item` → `inventory/items/`
   - `ingest-candidate`, `question`, `task`, `artifact`, `watch` → `inventory/candidates/`
   - `entity` → `inventory/entities/`
   - `corpus` → `inventory/corpora/`
3. Write a markdown record with frontmatter per `references/inventory.md`.
4. Include the user's source/path/URL in `sources:` when provided.
5. Append to `log.md`:
   `## [YYYY-MM-DD] inventory | added <kind> <slug>`
6. Rebuild `inventory/_index.md` and the containing subdirectory `_index.md`.

### List

1. If `inventory/` or `inventory/_index.md` is missing, report that there are
   no inventory records yet and do not create files.
2. Read `inventory/_index.md` first.
3. If filters are present, search inventory records by frontmatter.
4. Present a compact chat-friendly result. Default to a Markdown table with
   title, kind, status, priority, next action, and updated date.
5. Use `--view` to choose columns:
   - `summary`: counts by kind/status plus the top records by priority
   - `actions`: records with `next_action`, sorted by priority then updated
   - `items`: item records with status, priority, quantity, next action, and updated date
   - `records`: one row per record with title/kind/status/priority/updated
   - `sources`: title plus compact source/origin pointers
6. Use `--format list` for short bullets when there are only a few records or
   when table cells would wrap badly. Use `--limit N` to cap the rows shown in
   chat. If more rows exist, report the hidden count and where the full index
   or saved view lives.
7. Do not read every record body just to list inventory. Use indexes and
   frontmatter first; open full records only when requested fields are not in an
   index or the user asks for detail.

### Save View

1. Build the same filtered result as `list`, using the requested `--view`,
   `--kind`, `--status`, `--priority`, and `--limit` filters.
2. Write a derived markdown view under `inventory/views/<slug>.md`.
3. View files are not inventory records. Use lightweight view frontmatter:
   `title`, `view`, `filters`, `updated`, `summary`.
4. Rebuild `inventory/views/_index.md` and append to `log.md`:
   `## [YYYY-MM-DD] inventory | saved view <slug>`

### Scan Outputs

This is the migration discovery path. It must not write inventory files.

1. Scan `output/**/*.md`, excluding `_index.md` and `output/projects/*/WHY.md`.
2. Flag artifacts that look like durable tracking material:
   - filenames containing `queue`, `backlog`, `inventory`, `candidate`, `watch`, `sources`, `corpus`, or `dataset`
   - frontmatter titles containing those same terms
   - bodies with repeated tables of sources, priorities, statuses, URLs, or next actions
3. For each candidate, suggest a `migrate-output` command and likely kind.
4. For promising candidates, show a small sample of the proposed inventory
   shape: title, kind, status, priority, source, and next action. If the source
   looks too large, recommend one corpus record plus a dataset manifest or
   collection ingest instead of many inventory records.
5. Report: "No files were migrated. Run `inventory migrate-output <path> --apply` to create inventory records."

### Migrate Output

Default mode is dry-run. This creates a migration plan only:

1. Read the output artifact.
2. Infer one or more inventory records:
   - part lists, owned gear, SKUs, tools, hosts, or equipment rows → `item`
   - queue rows → `ingest-candidate`
   - named people/org/projects → `entity`
   - corpus/dataset/source collection descriptions → `corpus`
3. Preserve the original output path in frontmatter as `origin: output/...`.
4. Do **not** move or delete the source output. Inventory migration is additive.
5. In dry-run, show the proposed filenames and frontmatter only.
6. If the output would create more than about 10 records, dry-run must include
   only a representative sample and a recommendation. Ask for confirmation
   before `--apply`, unless the user already explicitly supplied `--apply`.
7. With `--apply`, write the proposed inventory records, update indexes, and append to `log.md`:
   `## [YYYY-MM-DD] inventory | migrated <output-path> -> N inventory records`

### Report

Always include:

- Inventory root path
- Records created/updated, if any
- Migration candidates found, if any
- Reminder when dry-run mode was used
