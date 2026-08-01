---
description: "Archive or restore whole topic wikis so old interests stay preserved but out of default context. Archived topics move under HUB/topics/.archive and are hidden from normal semantic and maintenance workflows."
argument-hint: "list [--archived] | topic <slug> [--reason \"why\"] | restore <slug> | peek <query> [--wiki <name>] [--include-archived]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(mkdir:*), Bash(mv:*), Bash(date:*), Bash(python3:*)
---

## Your task

Manage the archive lifecycle for topic wikis. Archive is a context filter, not
deletion: preserve the wiki, remove it from normal semantic workflows, and keep
explicit restore/maintenance possible.

Read `skills/wiki-manager/references/archive.md`,
`skills/wiki-manager/references/hub-resolution.md`, and
`skills/wiki-manager/references/wiki-structure.md` before mutating files.

### Resolve HUB

Archive is a hub-level operation. Resolve **HUB** with the standard protocol:

1. Read `$HOME/.config/llm-wiki/config.json`. Prefer `hub_path`, expanding only
   a leading `~`. Use `resolved_path` only as the legacy fallback described in
   `hub-resolution.md`.
2. If no config exists, try `$HOME/wiki/_index.md`.
3. Verify `HUB/wikis.json` and `HUB/topics/` exist, unless the subcommand is
   helping initialize/report an empty hub.
4. If the path can be statted but reading `wikis.json` or listing `topics/`
   fails with `Operation not permitted`, stop with the hub-resolution diagnostic
   and do not fall back to another path.

Do not archive project-local `.wiki/` directories in v1. Project archive remains
`/wiki:project archive`; inventory and dataset archive remain `status:
archived`.

### Parse $ARGUMENTS

Subcommands:

- **list**: show active topic wikis and archived counts. With `--archived`, show
  archived topics in a separate table.
- **topic <slug>**: archive an active topic wiki.
- **restore <slug>**: restore an archived topic wiki to active status.
- **peek <query>**: search archived topic indexes only and report possible
  matches without reading archived articles.

Flags:

- **--reason "why"**: optional archive reason stored in `wikis.json`.
- **--archived**: include archived topics in list output.
- **--include-archived**: allow explicit archived reads for `peek` or when a
  routed query follows an archived match.

If the input is empty, show the subcommands and examples.

### Archive Topic

For `topic <slug>`:

1. Refuse `slug = hub`.
2. Read `HUB/wikis.json`.
3. Resolve the active topic path:
   - Prefer a registry entry whose `status` is not `archived`.
   - Resolve registry paths as `<HUB>`, `~`, absolute, or HUB-relative.
   - If the registry is stale but `HUB/topics/<slug>/_index.md` exists, use it
     and repair the registry.
4. Fail if the source wiki is missing or already archived.
5. Fail if `HUB/topics/.archive/<slug>/` already exists.
6. `mkdir -p HUB/topics/.archive`
7. Move `HUB/topics/<slug>` to `HUB/topics/.archive/<slug>`.
8. Update `wikis.json`:
   - `path: "topics/.archive/<slug>"`
   - `status: "archived"`
   - `archived: YYYY-MM-DD`
   - `archive_reason: "<reason>"` when provided
9. Regenerate the hub `_index.md` active-topic table so archived topics do not
   appear as active. Include an archived count.
10. Append logs:
   - `HUB/log.md`: `## [YYYY-MM-DD] archive | archived topic <slug>`
   - archived topic `log.md`: same entry, if writable.
11. Report the old path, new path, and restore command.

Never delete topic content. Never move individual `raw/` or `wiki/` files.

### Restore Topic

For `restore <slug>`:

1. Locate the archived topic from `wikis.json` or
   `HUB/topics/.archive/<slug>/_index.md`.
2. Fail if `HUB/topics/<slug>/` already exists.
3. Move `HUB/topics/.archive/<slug>` to `HUB/topics/<slug>`.
4. Update `wikis.json`:
   - `path: "topics/<slug>"`
   - `status: "active"`
   - remove `archived` and `archive_reason`
   - add `restored: YYYY-MM-DD`
5. Stale-check the restored topic's master `_index.md` before reporting.
6. Append logs:
   - `HUB/log.md`: `## [YYYY-MM-DD] archive | restored topic <slug>`
   - restored topic `log.md`: same entry.
7. Report the restored path and suggest `/wiki:query --resume --wiki <slug>`.

On collision, do not overwrite. Report both paths and ask the user to resolve
the duplicate manually.

### List

For `list`:

1. Read `HUB/wikis.json`.
2. Build active and archived topic lists:
   - Active: registry entries with `status` absent or `active`, excluding `hub`.
   - Archived: entries with `status: archived` or paths beginning
     `topics/.archive/`.
   - Also detect `HUB/topics/.archive/*/_index.md` directories missing from the
     registry and report them as registry repair candidates.
3. Print a compact table of active topics by default.
4. With `--archived`, print a second archived table with slug, reason, archived
   date, and path.

Do not read archived articles during list. If an archived topic index is needed
for stats, read only its `_index.md`.

### Peek

For `peek <query>`:

1. Read only archived topic `_index.md` files and category indexes when cheap.
2. Match against titles, summaries, tags, and recent-change lines.
3. Return an `Archived Matches` section. Make clear that these matches are
   preserved context, not active evidence.
4. Suggest either:
   - `/wiki:archive restore <slug>` when the user wants to resume the topic, or
   - `/wiki:query "<question>" --wiki <slug> --include-archived` when they want
     an explicit archived lookup without restoring.

### Tool Interaction Reminder

Archived topics are hidden from normal query, compile, ingest,
ingest-collection, research, collect, output, plan, assess, inventory, dataset, project,
lessons-learned, librarian, refresh, and audit workflows. Deep query may surface
archived index matches separately, but must not cite them as active evidence
unless the user passes `--include-archived`.

`lint --include-archived` and `lint --archived-only` are the maintenance paths
for archived structure. `retract` may operate on archived sources when
explicitly targeted.

### Report

Always include:

- Hub path
- Action taken
- Topic slug(s)
- Active/archived path changes, if any
- Registry changes made
- Restore or follow-up command
