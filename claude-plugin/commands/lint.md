---
description: "Run health checks on the wiki. Find broken links, missing indexes, stale content, inconsistencies, and suggest improvements."
argument-hint: "[--fix] [--deep] [--wiki <name>] [--local]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*), Bash(mv:*), Bash(mkdir:*), WebSearch
---

## Your task

Follow the standard prelude in `skills/wiki-manager/references/command-prelude.md` (variant: **wiki-required** — stop with "No wiki found. Run `/wiki init` first." if missing).

Read the linting rules at `skills/wiki-manager/references/linting.md`. Then run health checks on the wiki.

### Parse $ARGUMENTS

- **--fix**: Automatically fix issues found (default: report only)
- **--deep**: Also use WebSearch to fact-check claims and find missing information

### Run Checks

Execute checks from `references/linting.md`. Order matters: C13 (alias rewrite) must run before C2 and C11 so downstream checks see canonical field names, and C11 (placement) must run before C3 so the index pass sees final file locations.

#### 1. C1: Structure (Critical)
Verify all required directories and `_index.md` files exist.

#### 2. C13: Frontmatter Aliases (Warning, runs early)
For every `.md` file's frontmatter, rewrite legacy keys and enum values to canonical form using the alias tables in `references/linting.md`. This is how frontmatter schema evolution is handled — there is no migration command. Fix first so subsequent checks see canonical fields.

#### 3. C2: Frontmatter (Critical/Warning)
Read each `.md` file's frontmatter. Check required fields exist and have valid values.

#### 4. C11: Canonical Placement (Critical)
For every `.md` file under `raw/` and `wiki/`, derive the expected directory from its frontmatter using the placement map in `references/linting.md` (raw `type` → `raw/<type>/`; wiki `category` → `wiki/concepts|topics|references/`; `type: thesis` → `wiki/theses/`). Flag files whose actual path doesn't match; auto-fix by `mv`. Flag content directories at the hub level. This heals both user mistakes and stale layouts from older wiki versions with the same code path. Does not touch `output/projects/` — that's C8's territory.

#### 5. C12: Unknown File Quarantine (Warning)
Walk `raw/`, `wiki/`, and the wiki root. Flag files and directories that are not in the allowlist for their location (per `references/linting.md` C12 table). Skip `output/` — C8 and C9 own that subtree.

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

#### 11. C8: Project Hygiene (Critical/Warning)
For each `output/projects/<slug>/_project.md`:
- Validate frontmatter (`type: project-manifest`, `goal`, `status`, `created`, `updated`)
- Verify `<!-- DERIVED -->` / `<!-- /DERIVED -->` delimiters present in the Members section
- Scan the project folder recursively (max 3 levels) and diff against the rendered Members list
- Check every markdown file inside the project folder has `project: <slug>` frontmatter
- Check that the `project:` value matches the containing folder slug
- Validate slug format (lowercase, hyphen-separated, ≤40 chars, no dates)

See `references/projects.md` § "Derived index regeneration" and `references/linting.md` § C8.

#### 12. C9: Project Candidates (Suggestion)
Scan `output/` (excluding `projects/`) for migration candidates:
- **Critical**: loose binaries (`.png`, `.jpg`, `.pdf`, `.csv`, `.svg`, `.zip`) in `output/` root — architecture violation
- **Critical**: any non-`projects/` subdirectory inside `output/` containing files — architecture violation
- **Suggestion**: markdown outputs with sibling binaries sharing a basename prefix (e.g., `article-foo.md` + `article-foo-hero.jpg`)
- **Suggestion**: ≥3 markdown outputs sharing a common prefix — strip dates, version tags (`-v\d+`, `-final`, `-release`), and type prefixes (`article-`, `output-`, `report-`) before comparing
- **Suggestion (fallback)**: ≥3 loose markdown outputs and no `output/projects/` folder exists — report as unmigrated wiki with a default single-project seed using the wiki slug. This catches topical clusters that don't share a leading prefix.

For each candidate cluster, compute a proposed slug per the heuristic in `references/linting.md` § C9 and output a ready-to-paste `/wiki:project new` + `/wiki:project add` block.

### If --fix

For each fixable issue, apply the auto-fix from the rules table in `references/linting.md`. Report what was fixed.

IMPORTANT: Only auto-fix issues with clear, unambiguous fixes — missing index entries, broken stats, stale `_project.md` Members sections, missing `project:` frontmatter on files already inside project folders, stale `output/_index.md` when `projects/` exists, legacy frontmatter keys/values (C13), files in the wrong canonical `raw/` or `wiki/` directory (C11), etc. Do NOT auto-fix content quality issues. Do NOT move files into projects — C9 candidates are human-authored via `/wiki:project new` + `/wiki:project add`. Never auto-delete unknown directories (C12) — warn only. On slug collisions during a C11 placement move, skip and warn. Do NOT rewrite articles.

### Report

Present the lint report in the format specified in `references/linting.md`, including the **Projects**, **Project Candidates**, and **Placement & Schema (C11/C12/C13)** sections. Update master `_index.md` with "Last lint" date. Append to `log.md`: `## [YYYY-MM-DD] lint | N checks, N critical, N warnings, N suggestions, N candidates, N auto-fixed`
