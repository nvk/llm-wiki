---
description: "Check if wiki articles are still current. Re-fetches sources, detects changes, and offers to update stale articles."
argument-hint: "[<article-path>|--due] [--wiki <name>] [--local]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*), WebFetch, WebSearch, Agent
---

## Your task

Follow the standard prelude in `skills/wiki-manager/references/command-prelude.md` (variant: **wiki-required** — stop with "No wiki found. Run `/wiki init` first." if missing).

Check whether wiki articles are still current by re-examining their sources. This is NOT automatic recompilation — it's a human-gated assessment of what may have changed.

### Parse $ARGUMENTS

- **article-path**: Path to a specific wiki article to refresh (e.g., `wiki/concepts/nvidia-spark.md`)
- **--due**: Check ALL articles past their volatility tier's staleness threshold. Present a numbered list for the user to select which ones to refresh.
- If neither is provided, show articles sorted by staleness (most overdue first) and ask which to check.

### Refresh Protocol

For each article being refreshed:

#### Tier 1: Source Check

1. Read the article's `sources:` frontmatter to get the list of raw source files
2. For each raw source, read its `source:` URL from frontmatter
3. Use WebFetch to re-fetch the URL content
4. Compare the fetched content against the stored raw source using key-fact extraction:
   - Extract 5-10 key claims/facts/numbers from the stored raw source
   - Check whether those same facts appear unchanged in the current version
   - Note any new sections, updated statistics, or changed conclusions
5. Classify each source as: **unchanged**, **updated** (new info available), **contradicted** (facts changed), or **unreachable** (URL 404/timeout)

#### Tier 2: Change Assessment

For sources classified as **updated** or **contradicted**:

1. Summarize what changed: new information added, statistics updated, conclusions revised, sections removed
2. Classify the change impact on the wiki article:
   - **Cosmetic**: formatting, typos, no factual change — no action needed
   - **Additive**: new information that could supplement the article — optional update
   - **Contradictory**: information that conflicts with the article's claims — update recommended

#### Tier 3: Action Decision

Present the assessment to the user with options per source:

```
## Refresh Report — <article title>

### Sources checked: N

1. **[Source Title]** — unchanged (last fetched: YYYY-MM-DD)
2. **[Source Title]** — updated (additive)
   What changed: New benchmarks published for 2026 Q2, 15% performance improvement reported
   → skip | update | flag
3. **[Source Title]** — unreachable (HTTP 404)
   → skip | retract

### Article freshness
Current: volatility hot, verified 45 days ago
Recommendation: update sources 2, retract source 3
```

On user selection:
- **skip**: No changes. Update `verified` date to today (human confirmed it's still accurate).
- **update**: Re-ingest the changed source (overwrite the raw file with new content, preserve frontmatter), then recompile the article following the standard compilation protocol.
- **flag**: Degrade the article's `confidence` by one level (high→medium, medium→low). Add a note to the article body: `> ⚠️ Some sources for this article may have changed since last verification. Run /wiki:refresh to update.`
- **retract**: Route to `/wiki:retract` for the unreachable source.

After all actions, update the article's `verified` date to today.

### --due Mode

When `--due` is set:

1. Read all wiki articles (glob `wiki/**/*.md`, exclude `_index.md`)
2. For each, read `volatility` and `verified` from frontmatter
3. Compute days since verified
4. Filter to articles past their tier's threshold (hot>30d, warm>90d, cold>365d)
5. Sort by overdue days (most overdue first)
6. Present as numbered list:

```
### Articles due for freshness review

1. [NVIDIA Spark Specs](wiki/topics/nvidia-spark.md) — hot, verified 62 days ago (32 days overdue)
2. [CLI UX Patterns](wiki/concepts/cli-ux-patterns.md) — warm, verified 105 days ago (15 days overdue)
3. [TCP/IP Fundamentals](wiki/references/tcp-ip.md) — cold, verified 400 days ago (35 days overdue)

Enter numbers (e.g. 1,2), "all", or "skip":
```

On selection, run the full refresh protocol for each selected article.

### Report & Log

After refreshing:
- Update each article's `verified` frontmatter to today
- Append to `log.md`: `## [YYYY-MM-DD] refresh | N articles checked, M updated, K flagged, J retracted`
- Append same to hub `log.md`

### Scheduled Refresh

For recurring freshness checks, use Claude Code's `/loop` command:

```
/loop 1d /wiki:refresh --due --wiki <name>
```

This checks overdue articles once daily while your session is open. The loop persists across `/resume` and expires after 7 days (re-create as needed).

For unattended scheduling, `/schedule` creates cloud-based routines — but these require the wiki to be in a git-cloneable repo (not local-only iCloud storage). If your wiki is local, `/loop` is the recommended approach.
