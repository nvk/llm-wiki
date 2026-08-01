---
description: "Run health checks on the wiki. Find broken links, missing indexes, stale content, archive registry drift, inconsistencies, and suggest improvements."
argument-hint: "[--fix] [--deep] [--include-archived] [--archived-only] [--wiki <name>] [--local]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*), Bash(mv:*), Bash(mkdir:*), WebSearch
---

## Your task

**Resolve the wiki.** Do NOT search the filesystem or read reference files — follow these steps:
1. Read `$HOME/.config/llm-wiki/config.json`. If it has `hub_path`, expand leading `~` only (not tildes in `com~apple~CloudDocs`) and prefer that path; use `resolved_path` only as a fallback cache when the expanded `hub_path` is unavailable and `resolved_path` is initialized. If config has only `resolved_path`, use it. If the configured path can be statted but reading `wikis.json` or listing `topics/` fails with `Operation not permitted`, stop and ask the user to grant Full Disk Access/iCloud Drive access to the launcher; do not fall back to `~/wiki` or `resolved_path`. Do not write machine-specific `resolved_path` into shared configs.
2. If no config → read `$HOME/wiki/_index.md`. If it exists → HUB = `$HOME/wiki`. If nothing found, ask the user where to create the wiki.
3. **Wiki location** (first match): `--local` → `.wiki/` in CWD; `--wiki <name>` → `HUB/wikis.json` lookup with portable path resolution (`<HUB>`, `~`, absolute, or HUB-relative); if the registry path is stale, fall back to `HUB/topics/<name>`; CWD has `.wiki/` → use it; else → HUB.
4. Read `<wiki>/_index.md` to verify. If missing → stop with "No wiki found. Run `/wiki init` first."

Read the linting rules at `skills/wiki-manager/references/linting.md`. Then run health checks on the wiki.

### Parse $ARGUMENTS

- **--fix**: Automatically fix issues found (default: report only)
- **--deep**: Also use WebSearch to fact-check claims and find missing information
- **--include-archived**: Include archived topic wikis in structural
  maintenance. Do not create freshness chores unless the user explicitly asks
  for a full archived maintenance pass.
- **--archived-only**: Check only archived topic wikis under
  `HUB/topics/.archive/`.

### Run Checks

Execute checks from `references/linting.md`. Order matters: C13 (alias rewrite) must run before C2 and C11 so downstream checks see canonical field names, and C11 (placement) must run before C3 so the index pass sees final file locations.

#### 1. C1: Structure (Critical)
Verify all required directories and `_index.md` files exist. Treat completely
absent `inventory/` and `datasets/` layers as unused optional layers, not
critical structure failures.

At the hub level, allow `topics/.archive/` as the archived-topic container. Do
not recursively lint archived topic content in a normal lint pass; report the
count as skipped unless `--include-archived` or `--archived-only` is set.

#### 2. C13: Frontmatter Aliases (Warning, runs early)
For every `.md` file's frontmatter, rewrite legacy keys and enum values to canonical form using the alias tables in `references/linting.md`. This is how frontmatter schema evolution is handled — there is no migration command. Fix first so subsequent checks see canonical fields.

#### 3. C2: Frontmatter (Critical/Warning)
Read each `.md` file's frontmatter. Check required fields exist and have valid values.

#### 4. C11: Canonical Placement (Critical)
For every `.md` file under `raw/` and `wiki/`, derive the expected directory from its frontmatter using the placement map in `references/linting.md` (raw `type` → `raw/<type>/`; wiki `category` → `wiki/concepts|topics|references/`; `type: thesis` → `wiki/theses/`). Flag files whose actual path doesn't match; auto-fix by `mv`. Flag content directories at the hub level. This heals both user mistakes and stale layouts from older wiki versions with the same code path. Does not touch `output/projects/` — that's C8's territory.

#### 5. C12: Unknown File Quarantine (Warning)
Walk `raw/`, `wiki/`, `inventory/`, `datasets/`, and the wiki root. Flag files and directories that are not in the allowlist for their location (per `references/linting.md` C12 table). Skip `output/` — C8 and C9 own that subtree.

#### 6. C3: Index Consistency (Warning)
Compare actual directory contents against `_index.md` entries. Verify statistics match. Runs after C11 because placement fixes may have changed which files live where — stale indexes will rebuild on next read per the Derived Index Protocol.

#### 7. C4: Link Integrity (Warning)
For each wiki article and inventory record, extract all markdown links. Verify each local markdown link resolves to an existing file. Check bidirectional "See Also" links for wiki articles.

#### 7b. C4b: Source Provenance (Warning)
For wiki articles, verify `sources:` frontmatter resolves to existing raw sources using the Source Reference Resolution protocol. For inventory records, verify local `sources:` entries resolve to existing `raw/`, `wiki/`, `output/`, `datasets/`, or `inventory/` paths; external URLs are allowed. Inventory sources are provenance for tracking state, not factual evidence.

#### 8. C5: Tag Hygiene (Warning)
Collect all tags across all files. Find near-duplicates. Check consistency between files and indexes.

#### 9. C6: Coverage (Suggestion)
Check that every raw source is referenced by at least one wiki article. Find orphan articles with no incoming links.

#### 10. C7: Deep Checks (only if --deep)
Use WebSearch to spot-check key claims. Identify stale content. Suggest new connections and articles.

#### 11. C8: Project Hygiene (Critical/Warning/Suggestion)
For each `output/projects/<slug>/` directory. Sub-check execution order matters — run C8c first so migrated projects pass C8a in the same lint pass:

1. **C8c** (run first): if a legacy `_project.md` is present, migrate it to `WHY.md` per the rule in `references/linting.md` § C8 (critical, auto-fixable — this is the first real application of lint-is-the-migration principle).
2. **C8a**: verify `WHY.md` exists and is non-empty (critical — projects without rationale become black boxes; LLMs rebuild wrong without the why).
3. **C8d**: slug format (warning — lowercase, hyphen-separated, ≤40 chars, no dates).
4. **C8b**: compute staleness by following each member file's `sources:` chain with the Source Reference Resolution protocol in `references/wiki-structure.md`. Preserve complete path entries, including spaces; never split source refs on whitespace. If any raw source has an `ingested:` newer than the member's `updated:`, flag the project (suggestion — human re-evaluates, never auto-fixed).

See `references/linting.md` § C8 for the full migration rule and `references/projects.md` for the architecture rationale.

#### 12. C9: Project Candidates (Suggestion)
Scan `output/` for architectural violations and migration candidates:
- **C9a** (critical): loose binaries in `output/` root — relative paths will break
- **C9b** (critical): non-`projects/` subdirectories containing files
- **C9c** (warning): `output/projects/<slug>/` folder without a `WHY.md`
- **C9d** (suggestion): ≥3 loose markdown outputs sharing a prefix — candidate for grouping

For each C9d cluster, output a ready-to-paste `/wiki:project new` + `/wiki:project add` block. Never auto-moved — grouping is a human decision.

#### 13. C14: Freshness (Warning/Info)
Compute composite freshness score (0-100) for each wiki article. Standard articles use four dimensions: source age, verification recency, compilation recency, source chain integrity. Articles with `compiled-from: conversation` use the two-dimension rebased formula from `references/linting.md` § C14. Decay curves scale by `volatility` tier. Flag articles below `freshness_threshold` from `config.md` (default 70).

#### 14. C15: Missing Volatility (Info)
Flag wiki articles lacking the `volatility` field. With `--fix`, add the safe default `volatility: warm`. See `references/linting.md` § C15.

#### 15. C16: Inventory Structure and Migration Candidates (Suggestion)
Check the inventory layer from `references/inventory.md` and `references/linting.md` § C16:

1. If `inventory/` is missing entirely, report that no inventory layer exists
   yet as a suggestion and do not create it just for lint.
2. If `inventory/` exists, verify `inventory/_index.md` and indexes for any
   existing subdirectories. If `--fix` is set, repair only the missing indexes
   for the existing layer or subdirectories.
3. Validate inventory record frontmatter when records exist.
4. Scan `output/**/*.md` for artifacts that look like durable inventory records, such as ingest queues, source backlogs, watch lists, candidate lists, or corpus inventories.
5. Report suggested `inventory migrate-output <path> --dry-run` commands with
   a compact sample shape when useful. Say when a candidate looks too small for
   inventory or too large and should become a dataset/collection instead. Never
   auto-convert outputs into inventory records.

#### 16. C17: Dataset Registry Structure and Migration Candidates (Suggestion)
Check the dataset registry from `references/datasets.md` and `references/linting.md` § C17:

1. If `datasets/` is missing entirely, report that no dataset registry exists
   yet as a suggestion and do not create it just for lint.
2. If `datasets/` exists, verify `datasets/_index.md`. For each
   `datasets/<slug>/MANIFEST.md`, verify `datasets/<slug>/_index.md`.
   Verify `samples/_index.md`, `profiles/_index.md`, and `queries/_index.md`
   only when those subdirectories already exist.
3. If `--fix` is set, repair only missing indexes for existing dataset
   directories. Do not create empty sample/profile/query folders or migrate
   content.
4. Validate dataset manifest frontmatter when manifests exist.
5. Scan `output/**/*.md` for artifacts that look like dataset manifests, such as corpus descriptions, archive inventories, dump summaries, parquet/sqlite/duckdb notes, or data profile reports.
6. Report suggested `dataset migrate-output <path> --dry-run` commands. Never auto-convert outputs, raw files, or inventory records into dataset manifests.

#### 17. C18: Missing Sources (Warning)
For each `.md` file in `wiki/` (excluding `_index.md`), verify that frontmatter has either a non-empty `sources:` list with at least one resolvable source, or `compiled-from: conversation`. Surface files with neither as missing provenance. Do not auto-fix.

#### 18. C19: Archive Lifecycle and Registry (Warning/Suggestion)
Check the archive lifecycle from `references/archive.md` and
`references/linting.md` § C19:

1. At the hub level, inspect `wikis.json` and `HUB/topics/.archive/`.
2. Report archived topics skipped by default.
3. If `--include-archived` is present, run structural checks against archived
   topic wikis in addition to active topics, but skip freshness/coverage pressure
   unless the user explicitly asks for a full archived maintenance pass.
4. If `--archived-only` is present, only check archived topic wikis.
5. Validate registry lifecycle state:
   - archived paths use `status: archived`
   - archived entries point to existing `topics/.archive/<slug>` roots
   - active entries do not point into `.archive`
   - filesystem-only archived topics are registry repair candidates
   - active/archive slug collisions are warnings and never auto-fixed
6. Surface active content that depends on archived paths as boundary-crossing
   provenance warnings.

### If --fix

For each fixable issue, apply the auto-fix from the rules table in `references/linting.md`. Report what was fixed.

IMPORTANT: Only auto-fix issues with clear, unambiguous fixes — missing index entries, dead index links, broken stats, legacy `_project.md` → `WHY.md` migration (C8c), stale `output/_index.md` when `projects/` exists, safe legacy frontmatter repairs (C13/C15), fuzzy raw-source refs that resolve to exactly one file, files in the wrong canonical `raw/` or `wiki/` directory (C11), missing indexes inside existing inventory or dataset layers (C16/C17), explicit uncompiled-source coverage references, etc. Do NOT auto-fix content quality issues. Do NOT create `WHY.md` with placeholder goals (C8a is warn-only — manufactured rationale is worse than the missing file). Do NOT create a completely absent optional inventory or dataset tree just to make placeholders. Do NOT move files into projects — C9 candidates are human-authored via `/wiki:project new` + `/wiki:project add`. Do NOT migrate output artifacts into inventory or dataset records — C16/C17 migration is explicit via `/wiki:inventory migrate-output --apply` or `/wiki:dataset migrate-output --apply`. Never auto-delete unknown directories (C12) — warn only. On slug collisions during a C11 placement move, skip and warn. Do NOT rewrite article bodies except for explicitly requested recompilation.

### Report

Present the lint report in the format specified in `references/linting.md`, including the **Projects**, **Project Candidates**, **Inventory**, **Datasets**, and **File Placement & Schema** sections. **Lead every user-visible line with a plain-English description of what happened — never with a check code (C1, C8c, etc.).** Check codes are internal identifiers for developers; humans reading the report need to see what was found and what was fixed, not which rule triggered it.

When listing a recommended fix priority, describe the action in human terms:
- Good: `Migrate 3 legacy project manifests (_project.md → WHY.md)`
- Bad: `C8c — migrate 3 _project.md → WHY.md`

Update master `_index.md` with "Last lint" date. Append to `log.md`: `## [YYYY-MM-DD] lint | N checks, N critical, N warnings, N suggestions, N candidates, N auto-fixed`
