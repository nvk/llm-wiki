---
description: "Review wiki content for staleness, quality, accuracy, and coherence. Produces scored reports; never modifies content without confirmation."
argument-hint: "scan [--article <path>] [--resume] [--passes <list>] | report | fix <id> [--wiki <name>] [--local]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*), Bash(mv:*), Bash(mkdir:*), WebFetch, WebSearch, Agent
---

## Your task

**Resolve the wiki.** Do NOT search the filesystem or read reference files — follow these steps:
1. Read `$HOME/wiki/_index.md`. If it exists → HUB = `$HOME/wiki`. Skip to step 3.
2. If not → read `$HOME/.config/llm-wiki/config.json`. Use `resolved_path` as HUB. If only `hub_path` exists, expand leading `~` only (not tildes in `com~apple~CloudDocs`), set HUB, write `resolved_path` back. If no config → HUB = `$HOME/wiki`.
3. **Wiki location** (first match): `--local` → `.wiki/` in CWD; `--wiki <name>` → `HUB/wikis.json` lookup; CWD has `.wiki/` → use it; else → HUB.
4. Read `<wiki>/_index.md` to verify. If missing → stop with "No wiki found. Run `/wiki init` first."

Read the librarian reference at `skills/wiki-manager/references/librarian.md`. Then execute the requested subcommand.

### Parse $ARGUMENTS

First argument is the subcommand:

- **scan**: Score all wiki articles for staleness and quality. Default subcommand if none specified.
- **report**: Display the latest `.librarian/REPORT.md`. If no report exists, suggest running `scan` first.
- **fix <id>**: (Phase 3, not yet implemented) Apply a proposed fix. Respond: "Fix operations are not yet available. Use the report to identify issues and address them manually."

Flags (apply to `scan`):

- **--article <path>**: Scan only this article instead of the full wiki. Path relative to wiki root (e.g., `wiki/concepts/librarian-agent.md`).
- **--resume**: Explicitly resume from checkpoint. Also happens automatically if `checkpoint.json` exists.
- **--passes <list>**: Comma-separated list of passes to run. Default: `staleness,quality`. Future: `verification,coherence,dedup`.
- **--wiki <name>**: Target a specific topic wiki.
- **--local**: Use project-local `.wiki/`.

### Scan Protocol

#### 0. Initialize

1. Create `.librarian/` directory if it doesn't exist (`mkdir -p`).
2. Check for existing `checkpoint.json`:
   - If exists and `--resume` or no explicit flag: read it, report how many articles are already done, continue from where it left off.
   - If exists and user started a fresh scan (no `--resume`): warn "Found checkpoint from [date] with N/M articles done. Resume? (y/n)". On "n", delete checkpoint and start fresh.
3. Read `config.md` for `freshness_threshold` (default: 70).
4. Build article list:
   - Full scan: `Glob wiki/**/*.md`, exclude `_index.md` files.
   - `--article`: just the one file.
5. Subtract already-completed articles (from checkpoint) to get the pending list.

#### 1. Staleness Pass (per article)

For each pending article:

1. Read the article's YAML frontmatter (do NOT read the full body yet — Tier 1 is metadata-only).
2. Read `volatility` (default: `warm`), `verified`, `updated`, `created`, `sources`, `confidence`.
3. For each entry in `sources:`, check if the raw file exists (Glob or Read). Record resolved count.
4. For resolved sources, read their `ingested:` date from frontmatter.
5. Compute staleness score using the formula in `references/librarian.md` § Staleness Scoring.
6. Write result to `checkpoint.json` (atomic: write `.checkpoint.tmp`, rename).

#### 2. Quality Pass (per article)

For each article (same loop, immediately after staleness):

**Tier 1 (all articles, metadata-only)**:

1. Count sources and read their `confidence:` fields → source quality score (1-5).
2. Get file size (`wc -w` or estimate from Read) and count `## ` headings → depth proxy (1-5).
3. Check for "See Also" section presence → flag `no-see-also` if missing.
4. Record Tier 1 quality scores in checkpoint.

**Tier 2 escalation** — read the full article body if ANY of these are true:
- Staleness score < threshold (from Pass 1)
- `volatility: hot`
- Tier 1 depth proxy = 1 or 2 (suspected stub)

When escalated:

5. Read the full article body.
6. Score coherence (1-5): Does it flow logically? Are there unsupported jumps?
7. Score utility (1-5): Would a reader find this actionable?
8. Refine depth and source quality scores with body-level evidence.
9. Apply quality flags per `references/librarian.md` § Quality Flags.
10. Update checkpoint with Tier 2 results.

**Non-escalated articles**: coherence and utility default to 3 (adequate). This avoids reading every article body on large wikis.

#### 3. Stale Article Triage

After all articles are scored:

1. Sort articles by staleness score (ascending — worst first).
2. Filter to those below the freshness threshold.
3. For each stale article, recommend an action:
   - `refresh` — sources are old, article may be outdated. Delegate to `/wiki:refresh`.
   - `verify` — article lacks `verified:` date or it's been too long. User should read and confirm.
   - `expand` — thin article with few sources. Suggest `/wiki:research` to find more sources.
4. Present the triage list to the user:

```
## Stale Articles — Action Required

1. [NVIDIA Spark Specs](wiki/topics/nvidia-spark.md) — score 31/100
   Sources 180 days old, never verified.
   → Refresh sources? (y/n/skip)

2. [CLI UX Patterns](wiki/concepts/cli-ux-patterns.md) — score 45/100
   Verified 120 days ago, warm volatility.
   → Verify still accurate? (y/n/skip)
```

5. For articles the user selects to refresh: invoke the refresh protocol from `commands/refresh.md` for that article.
6. For articles the user selects to verify: update `verified:` to today in the article's frontmatter.

#### 4. Generate Reports

1. Compile all results from checkpoint into `scan-results.json` (format per `references/librarian.md`).
2. Generate `REPORT.md` from the JSON (format per `references/librarian.md`).
3. Delete `checkpoint.json` (scan complete — no longer needed).
4. Write both files to `.librarian/`.

#### 5. Log and Report

1. Append to `.librarian/log.md`:
   `## [YYYY-MM-DD] scan | N articles, M stale, K low-quality (passes: staleness, quality)`

2. Append to the wiki's `log.md`:
   `## [YYYY-MM-DD] librarian | scanned N articles, M stale, K low-quality`

3. Present the summary to the user:

```
## Librarian Scan Complete

Scanned N articles in <wiki-name>.

| Metric | Value |
|--------|-------|
| Below staleness threshold | M |
| Low quality (< 50) | K |
| Average staleness | X/100 |
| Average quality | Y/100 |

Full report: .librarian/REPORT.md
Scan data: .librarian/scan-results.json
```

4. If stale articles were found and user hasn't triaged them yet, prompt for triage (step 3 above).

### Report Subcommand

When the user runs `report` (or `/wiki:librarian report`):

1. Check if `.librarian/REPORT.md` exists. If not: "No librarian report found. Run `/wiki:librarian scan` first."
2. Read and display `REPORT.md`.
3. Note when the scan was run (from `scan-results.json` → `completed_at`).
4. If the scan is older than the wiki's staleness threshold for hot articles (30 days), suggest re-scanning.
