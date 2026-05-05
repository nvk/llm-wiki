---
description: "Manage dataset manifests for data that is too large or unsuitable to store directly in the wiki. The wiki becomes the index/interface; the data stays external."
argument-hint: "list [--status <status>] [--storage <mode>] [--view summary|manifests|schema|locations] [--limit N] [--format table|list] | add \"<title>\" [--location <path-or-url>] [--format <fmt>] | show <slug-or-path> | scan-outputs [--dry-run] | migrate-output <output-path> [--dry-run|--apply] | profile <slug> [--dry-run|--apply] | sample <slug> [--limit N] [--dry-run|--apply] [--wiki <name>] [--local]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*), Bash(mkdir:*), Bash(du:*), Bash(stat:*), Bash(head:*), Bash(file:*)
---

## Your task

**Resolve the wiki.** Do NOT broadly search the filesystem — follow these steps:
1. Read `$HOME/.config/llm-wiki/config.json`. If it has `resolved_path` → HUB = that value, skip to step 3. If only `hub_path`, expand leading `~` only (not tildes in `com~apple~CloudDocs`), set HUB, write `resolved_path` back, skip to step 3.
2. If no config → read `$HOME/wiki/_index.md`. If it exists → HUB = `$HOME/wiki`. If nothing found, ask the user where to create the wiki.
3. **Wiki location** (first match): `--local` → `.wiki/` in CWD; `--wiki <name>` → `HUB/wikis.json` lookup; CWD has `.wiki/` → use it; else → HUB.
4. Read `<wiki>/_index.md` to verify. If missing → stop with "No wiki found. Run `/wiki init` first."

After resolving the wiki, read the dataset reference at `skills/wiki-manager/references/datasets.md`, then run the requested subcommand.

Dataset manifests are for large or external data that should not be copied into
`raw/` or `wiki/`. The wiki stores pointers, schema notes, small samples,
profiles, query recipes, and provenance. Actual datasets remain at their
original filesystem path, object store, URL, database, or archive.

### Parse $ARGUMENTS

Subcommands:

- **list**: List dataset manifests, optionally filtered by status/storage and view mode.
- **add "<title>"**: Create a dataset manifest under `datasets/<slug>/`.
- **show <slug-or-path>**: Read one dataset manifest and related profile/sample indexes.
- **scan-outputs [--dry-run]**: Find output artifacts that describe datasets but still live in `output/`.
- **migrate-output <output-path> [--dry-run|--apply]**: Convert one legacy output artifact into one or more dataset manifests. Default is **dry-run**. `--apply` is required to write.
- **profile <slug> [--dry-run|--apply]**: Record lightweight dataset size/format/schema observations. Never load the full dataset into the wiki.
- **sample <slug> [--limit N] [--dry-run|--apply]**: Save a tiny representative sample or sample recipe under the dataset folder.

Statuses:
`proposed`, `active`, `external`, `archived`, `unavailable`.

Storage modes:
`local`, `remote`, `external`, `hybrid`.

Schema statuses:
`unknown`, `inferred`, `declared`, `validated`.

### Ensure Structure

Before any write:

1. Ensure `datasets/` exists with `_index.md`.
2. For a specific dataset write, ensure:
   - `datasets/<slug>/MANIFEST.md`
   - `datasets/<slug>/_index.md`
   - `datasets/<slug>/samples/_index.md`
   - `datasets/<slug>/profiles/_index.md`
   - `datasets/<slug>/queries/_index.md`
3. Missing structure may be created, but never move or copy user datasets into the wiki.

### Add

1. Slugify the title using normal wiki filename rules.
2. Create `datasets/<slug>/` with `samples/`, `profiles/`, and `queries/` subdirectories.
3. Write `MANIFEST.md` with frontmatter per `references/datasets.md`.
4. Record any `--location`, `--format`, size, access, license, or source hints provided by the user.
5. Append to `log.md`:
   `## [YYYY-MM-DD] dataset | added <slug>`
6. Rebuild `datasets/_index.md`.

### List

1. Read `datasets/_index.md` first.
2. If filters require fields not present in the index, read only
   `datasets/*/MANIFEST.md` frontmatter. Do not inspect samples, profiles,
   queries, or underlying data for a list operation.
3. Present a compact chat-friendly result. Default to a Markdown table with
   dataset, status, storage, formats, size, records, schema status, and updated
   date.
4. Use `--view` to choose columns:
   - `summary`: counts by status/storage plus the most actionable manifests
   - `manifests`: one row per manifest
   - `schema`: schema status, formats, record count, profile availability
   - `locations`: compact storage/access/location pointers
5. Use `--format list` for short bullets when paths or URLs would make a table
   unreadable. Use `--limit N` to cap rows in chat and report the hidden count.

### Scan Outputs

This is the migration discovery path. It must not write dataset manifests.

1. Scan `output/**/*.md`, excluding `_index.md` and `output/projects/*/WHY.md`.
2. Flag artifacts that look like dataset descriptions:
   - filenames or titles containing `dataset`, `data`, `corpus`, `archive`, `dump`, `warehouse`, `lake`, `parquet`, `sqlite`, `duckdb`, `csv`, `jsonl`, or `snapshot`
   - bodies with fields/tables for size, rows, schema, license, storage path, query recipes, or sample excerpts
3. Suggest a `dataset migrate-output <path> --dry-run` command for each candidate.
4. Report: "No dataset manifests were created. Run `dataset migrate-output <path> --apply` to create manifests."

### Migrate Output

Default mode is dry-run. This creates a migration plan only:

1. Read the output artifact.
2. Infer one or more dataset manifests.
3. Preserve the original output path in frontmatter as `origin: output/...`.
4. Preserve any cited data locations in `locations:`.
5. Do **not** move or delete the source output.
6. Do **not** copy the underlying dataset into the wiki.
7. In dry-run, show proposed manifest paths and frontmatter only.
8. With `--apply`, write proposed manifests, update indexes, and append to `log.md`:
   `## [YYYY-MM-DD] dataset | migrated <output-path> -> N manifests`

### Profile

Profiling is intentionally lightweight:

1. Read the manifest and resolve `locations:`.
2. If a location is local and safely accessible, collect only metadata:
   - byte size via `du` or `stat`
   - file type via extension or `file`
   - first line/header for text tabular data
   - row count only if cheap and bounded
3. For remote locations, record planned profile steps instead of fetching large data.
4. Dry-run by default unless `--apply` is present.
5. With `--apply`, write a dated profile note under `datasets/<slug>/profiles/` and update `MANIFEST.md` summary fields if unambiguous.

### Sample

Samples must stay tiny and representative:

1. Default `--limit` is 20 rows or equivalent.
2. If the dataset is remote or compressed/large, write a sampling recipe instead of fetching.
3. Never save secrets, private data, or more than a small excerpt.
4. Dry-run by default unless `--apply` is present.
5. With `--apply`, write under `datasets/<slug>/samples/` and update indexes.

### Report

Always include:

- Dataset registry path
- Manifests created/updated, if any
- Migration candidates found, if any
- Reminder when dry-run mode was used
