---
description: "Run health checks on the wiki. Find broken links, missing indexes, stale content, inconsistencies, and suggest improvements."
argument-hint: "[--fix] [--deep] [--wiki <name>] [--local]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*), WebSearch
---

## Your task

First, resolve **HUB** by following the protocol in `references/hub-resolution.md` (read config, expand leading `~` only, quote paths with spaces). Then check if a wiki exists by trying to read `HUB/_index.md` (global hub) and `.wiki/_index.md` (local).

Read the linting rules at `skills/wiki-manager/references/linting.md`. Then run health checks on the wiki.

### Resolve wiki location

1. `--local` → `.wiki/`
2. `--wiki <name>` → look up in `HUB/wikis.json`
3. Current directory has `.wiki/` → use it
4. Otherwise → HUB

If wiki does not exist, stop: "No wiki found. Run `/wiki init` first."

### Parse $ARGUMENTS

- **--fix**: Automatically fix issues found (default: report only)
- **--deep**: Also use WebSearch to fact-check claims and find missing information

### Run Checks

Execute checks from `references/linting.md` in order:

#### 1. C1: Structure (Critical)
Verify all required directories and `_index.md` files exist.

#### 2. C2: Frontmatter (Critical/Warning)
Read each `.md` file's frontmatter. Check required fields exist and have valid values.

#### 3. C3: Index Consistency (Warning)
Compare actual directory contents against `_index.md` entries. Verify statistics match.

#### 4. C4: Link Integrity (Warning)
For each wiki article, extract all markdown links. Verify each resolves to an existing file. Check bidirectional "See Also" links.

#### 5. C5: Tag Hygiene (Warning)
Collect all tags across all files. Find near-duplicates. Check consistency between files and indexes.

#### 6. C6: Coverage (Suggestion)
Check that every raw source is referenced by at least one wiki article. Find orphan articles with no incoming links.

#### 7. C7: Deep Checks (only if --deep)
Use WebSearch to spot-check key claims. Identify stale content. Suggest new connections and articles.

### If --fix

For each fixable issue, apply the auto-fix from the rules table in `references/linting.md`. Report what was fixed.

IMPORTANT: Only auto-fix issues that have clear, unambiguous fixes (missing index entries, broken stats, etc.). Do NOT auto-fix content quality issues or rewrite articles.

### Report

Present the lint report in the format specified in `references/linting.md`. Update master `_index.md` with "Last lint" date. Append to `log.md`: `## [YYYY-MM-DD] lint | N checks, N critical, N warnings, N suggestions, N auto-fixed`
