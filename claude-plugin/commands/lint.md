---
description: "Run health checks on the wiki. Find broken links, missing indexes, stale content, inconsistencies, and suggest improvements."
argument-hint: "[--fix] [--deep] [--wiki <name>] [--local]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*), Bash(mv:*), Bash(mkdir:*), WebSearch
---

## Your task

**Resolve the wiki.** Do NOT search the filesystem or read reference files — follow these steps:
1. Read `$HOME/.config/llm-wiki/config.json`. If it has `resolved_path` → HUB = that value, skip to step 3. If only `hub_path`, expand leading `~` only (not tildes in `com~apple~CloudDocs`), set HUB, write `resolved_path` back, skip to step 3.
2. If no config → read `$HOME/wiki/_index.md`. If it exists → HUB = `$HOME/wiki`. If nothing found, ask the user where to create the wiki.
3. **Wiki location** (first match): `--local` → `.wiki/` in CWD; `--wiki <name>` → `HUB/wikis.json` lookup; CWD has `.wiki/` → use it; else → HUB.
4. Read `<wiki>/_index.md` to verify. If missing → stop with "No wiki found. Run `/wiki init` first."

Read the linting rules at `skills/wiki-manager/references/linting.md`. Then run health checks on the wiki.

### Parse $ARGUMENTS

- **--fix**: Automatically fix issues found (default: report only)
- **--deep**: Also use WebSearch to fact-check claims and find missing information

### Run Checks

Execute checks from `references/linting.md`. Order matters: C13 (alias rewrite) must run before C2 and C11 so downstream checks see canonical field names, and C11 (placement) must run before C3 so the index pass sees final file locations.

#### 1. C1: Structure (Critical)
Verify all required directories and `_index.md` files exist, including the `inventory/` layer when present.

#### 2. C13: Frontmatter Aliases (Warning, runs early)
For every `.md` file's frontmatter, rewrite legacy keys and enum values to canonical form using the alias tables in `references/linting.md`. This is how frontmatter schema evolution is handled — there is no migration command. Fix first so subsequent checks see canonical fields.

#### 3. C2: Frontmatter (Critical/Warning)
Read each `.md` file's frontmatter. Check required fields exist and have valid values.

#### 4. C11: Canonical Placement (Critical)
For every `.md` file under `raw/` and `wiki/`, derive the expected directory from its frontmatter using the placement map in `references/linting.md` (raw `type` → `raw/<type>/`; wiki `category` → `wiki/concepts|topics|references/`; `type: thesis` → `wiki/theses/`). Flag files whose actual path doesn't match; auto-fix by `mv`. Flag content directories at the hub level. This heals both user mistakes and stale layouts from older wiki versions with the same code path. Does not touch `output/projects/` — that's C8's territory.

#### 5. C12: Unknown File Quarantine (Warning)
Walk `raw/`, `wiki/`, `inventory/`, and the wiki root. Flag files and directories that are not in the allowlist for their location (per `references/linting.md` C12 table). Skip `output/` — C8 and C9 own that subtree.

#### 6. C3: Index Consistency (Warning)
Compare actual directory contents against `_index.md` entries. Verify statistics match. Runs after C11 because placement fixes may have changed which files live where — stale indexes will rebuild on next read per the Derived Index Protocol.

#### 7. C4: Link Integrity (Warning)
For each wiki article, extract all markdown links. Verify each resolves to an existing file. Check bidirectional "See Also" links.

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
Compute composite freshness score (0-100) for each wiki article from four dimensions: source age, verification recency, compilation recency, source chain integrity. Decay curves scale by `volatility` tier. Flag articles below `freshness_threshold` from `config.md` (default 70). See `references/linting.md` § C14.

#### 14. C15: Missing Volatility (Info)
Flag wiki articles lacking the `volatility` field. See `references/linting.md` § C15.

#### 15. C16: Inventory Structure and Migration Candidates (Suggestion)
Check the inventory layer from `references/inventory.md` and `references/linting.md` § C16:

1. Verify `inventory/`, `inventory/candidates/`, `inventory/entities/`, `inventory/corpora/`, and `inventory/views/` have `_index.md` files. Missing inventory structure is a migration opportunity for older wikis, not corruption.
2. If `--fix` is set, create only the missing inventory directories and empty indexes. Do not migrate content.
3. Validate inventory record frontmatter when records exist.
4. Scan `output/**/*.md` for artifacts that look like durable inventory records, such as ingest queues, source backlogs, watch lists, candidate lists, or corpus inventories.
5. Report suggested `inventory migrate-output <path> --dry-run` commands. Never auto-convert outputs into inventory records.

### If --fix

For each fixable issue, apply the auto-fix from the rules table in `references/linting.md`. Report what was fixed.

IMPORTANT: Only auto-fix issues with clear, unambiguous fixes — missing index entries, broken stats, legacy `_project.md` → `WHY.md` migration (C8c), stale `output/_index.md` when `projects/` exists, legacy frontmatter keys/values (C13), files in the wrong canonical `raw/` or `wiki/` directory (C11), missing empty inventory directories/indexes (C16), etc. Do NOT auto-fix content quality issues. Do NOT create `WHY.md` with placeholder goals (C8a is warn-only — manufactured rationale is worse than the missing file). Do NOT move files into projects — C9 candidates are human-authored via `/wiki:project new` + `/wiki:project add`. Do NOT migrate output artifacts into inventory records — C16 migration is explicit via `/wiki:inventory migrate-output --apply`. Never auto-delete unknown directories (C12) — warn only. On slug collisions during a C11 placement move, skip and warn. Do NOT rewrite articles.

### Report

Present the lint report in the format specified in `references/linting.md`, including the **Projects**, **Project Candidates**, **Inventory**, and **File Placement & Schema** sections. **Lead every user-visible line with a plain-English description of what happened — never with a check code (C1, C8c, etc.).** Check codes are internal identifiers for developers; humans reading the report need to see what was found and what was fixed, not which rule triggered it.

When listing a recommended fix priority, describe the action in human terms:
- Good: `Migrate 3 legacy project manifests (_project.md → WHY.md)`
- Bad: `C8c — migrate 3 _project.md → WHY.md`

Update master `_index.md` with "Last lint" date. Append to `log.md`: `## [YYYY-MM-DD] lint | N checks, N critical, N warnings, N suggestions, N candidates, N auto-fixed`
