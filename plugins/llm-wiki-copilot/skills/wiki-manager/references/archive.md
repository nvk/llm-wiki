# Archive Lifecycle

Archive preserves knowledge while removing it from normal working context. It is
for material the user no longer wants active tools to load by default, not for
bad evidence or deleted content.

## Scope

Archive operates at the topic-wiki lifecycle level in v1:

- Hub topic wikis move from `HUB/topics/<slug>/` to
  `HUB/topics/.archive/<slug>/`.
- Project archive remains the existing `output/projects/.archive/<slug>/`
  workflow from `projects.md`.
- Inventory and dataset archive remain their existing `status: archived`
  frontmatter values.
- Individual `raw/` or `wiki/` file archive is intentionally out of scope.
  Moving single source/article files breaks exact `sources:` references,
  backlinks, and coverage checks. If enough material is no longer wanted, the
  topic boundary should be archived or split.

## Lifecycle Commands

### `archive topic <slug>`

1. Resolve HUB with the standard hub-resolution protocol.
2. Refuse to archive `hub`.
3. Locate the active topic in this order:
   - `wikis.json` entry whose `status` is not `archived`
   - `HUB/topics/<slug>/`
4. Fail if `HUB/topics/.archive/<slug>/` already exists.
5. Move `HUB/topics/<slug>/` to `HUB/topics/.archive/<slug>/`.
6. Update `wikis.json`:
   ```json
   "<slug>": {
     "path": "topics/.archive/<slug>",
     "description": "...",
     "status": "archived",
     "archived": "YYYY-MM-DD",
     "archive_reason": "optional user reason"
   }
   ```
7. Update the hub `_index.md` so active topic listings exclude this wiki and
   archived counts remain visible.
8. Append to both hub `log.md` and the archived topic's own `log.md`:
   `## [YYYY-MM-DD] archive | archived topic <slug>`.

### `archive restore <slug>`

1. Resolve HUB.
2. Locate the archived topic from `wikis.json` or
   `HUB/topics/.archive/<slug>/`.
3. Fail if `HUB/topics/<slug>/` already exists.
4. Move `HUB/topics/.archive/<slug>/` to `HUB/topics/<slug>/`.
5. Update `wikis.json` path to `topics/<slug>`, set `status: active`, remove
   `archived` and `archive_reason`, and set `restored: YYYY-MM-DD`.
6. Stale-check the restored wiki's master `_index.md`.
7. Append archive/restore log entries.

### `archive list`

List active topics by default and show an archived count. With `--archived`,
include archived topics in a separate table. Do not read archived topic
articles; use registry metadata and `_index.md` only when needed.

### `archive peek <query>`

Optional convenience mode for discovery. Read archived topic `_index.md` files
only, search summaries/tags for a query, and report matches separately from
active material. Do not read archived articles unless the user then asks to
restore or explicitly includes archived content in a query.

## Visibility Contract

Archive is a context filter, not a deletion mechanism.

| Workflow | Default behavior |
|----------|------------------|
| `wiki status` | Show active stats and `Archived topics: N`; list archived only with `--archived` |
| `query --quick` / standard / `--list` | Exclude archived topics and archived supplementary wikis |
| `query --deep` | Peek archived topic indexes and report separate Archived Matches; do not cite them as active evidence |
| `query --include-archived` | Fully search/read archived material and label it in citations |
| `research` | Ignore archived wikis; warn when an archived topic title strongly overlaps the requested topic |
| `ingest` / `ingest-collection` | Do not route into archived wikis unless the user explicitly restores or forces archived access |
| `compile` | Active wikis only by default; explicit archived target compiles inside archive but never makes it active |
| `inventory`, `dataset`, `project`, `lessons-learned` | Reject archived targets unless explicitly included; distinguish topic archive from record/dataset/project archive states |
| `output`, `plan`, `assess` | Ignore archived unless `--include-archived`; label archived-derived context clearly |
| `init` / `--new-topic` | Treat archived slugs as collisions; restore or choose a new slug instead of creating an active duplicate |
| `librarian` / `refresh` | Skip archived by default; archived material should not create freshness chores |
| `audit` | Skip archived by default, except when the targeted artifact depends on archived material |
| `retract` | May operate on archived sources when explicitly targeted; bad preserved evidence still needs retraction |
| `lint` | Active structural checks by default; `--include-archived` and `--archived-only` maintain archived structure explicitly |

## Lint Semantics

Lint is responsible for keeping archive structure coherent, but normal lint
should not resurrect archived maintenance debt.

- Default hub lint validates the active registry and reports archived topic
  counts as skipped.
- `lint --include-archived` checks archived topic structure in addition to
  active material.
- `lint --archived-only` checks only archived topic wikis.
- `lint --fix --include-archived` may perform mechanical fixes on archived
  content: indexes, canonical placement, frontmatter aliases, dead index rows,
  and safe source-reference rewrites.
- Freshness, librarian quality pressure, orphan-source pressure, and
  uncompiled-source coverage should be skipped for archived content unless the
  user explicitly asks for a full archived maintenance pass.

## Cross-Boundary Links

Whole-topic archive preserves internal relative links. Cross-boundary links need
labels:

- active -> active: normal
- archived -> archived: normal
- archived -> active: allowed
- active -> archived: warning; active content now depends on quiet material

An active article citing an archived raw source is allowed but should be
reported by lint as a boundary-crossing provenance warning. Do not break the
source chain just because lifecycle state changed.

## Registry Repair

`wikis.json` is the lifecycle source of truth, but lint should repair common
filesystem drift:

- If `HUB/topics/.archive/<slug>/_index.md` exists and the registry points to
  `topics/<slug>` with no active directory, update the path and set
  `status: archived`.
- If a registry entry says `archived` but `HUB/topics/<slug>/_index.md` exists
  and the archived directory does not, update the path to `topics/<slug>` and
  set `status: active`.
- If both active and archived directories exist for the same slug, do not choose
  automatically. Report a collision.

## Local Wikis

Do not move project-local `.wiki/` directories in v1. A local wiki can still
contain archived inventory records, dataset manifests, or projects, but topic
archive is a hub-level lifecycle operation. If a local wiki needs to go quiet,
the user can move/rename the project or register it in the hub and archive the
registered topic later.
