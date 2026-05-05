---
description: "Check if wiki articles are still current. Re-fetches sources, detects changes, and offers to update stale articles."
argument-hint: "[<article-path>|--due] [--wiki <name>] [--local]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*), WebFetch, WebSearch, Agent
---

## Your task

**Resolve the wiki.** Do NOT search the filesystem or read reference files — follow these steps:
1. Read `$HOME/.config/llm-wiki/config.json`. If it has `resolved_path` → HUB = that value, skip to step 3. If only `hub_path`, expand leading `~` only (not tildes in `com~apple~CloudDocs`), set HUB, write `resolved_path` back, skip to step 3.
2. If no config → read `$HOME/wiki/_index.md`. If it exists → HUB = `$HOME/wiki`. If nothing found, ask the user where to create the wiki.
3. **Wiki location** (first match): `--local` → `.wiki/` in CWD; `--wiki <name>` → `HUB/wikis.json` lookup; CWD has `.wiki/` → use it; else → HUB.
4. Read `<wiki>/_index.md` to verify. If missing → stop with "No wiki found. Run `/wiki init` first."

Check whether wiki articles are still current by re-examining their sources. This is NOT automatic recompilation — it's a human-gated assessment of what may have changed.

Inventory awareness: if refresh finds a source that needs later follow-up,
monitoring, replacement, or access repair, offer an inventory record or update
an existing one. Do not create records for every minor stale article; reserve
inventory for durable watch items and blocked actions.

### Parse $ARGUMENTS

- **article-path**: Path to a specific wiki article to refresh (e.g., `wiki/concepts/nvidia-spark.md`)
- **--due**: Check ALL articles past their volatility tier's staleness threshold. Present a numbered list for the user to select which ones to refresh.
- If neither is provided, show articles sorted by staleness (most overdue first) and ask which to check.

### Refresh Protocol

For each article being refreshed:

#### Tier 1: Source Check

1. Read the article's `sources:` frontmatter to get the list of raw source files. Resolve each entry with the Source Reference Resolution protocol in `references/wiki-structure.md`; preserve paths with whitespace and never split entries on whitespace.
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
4. Read `freshness_threshold` from `config.md` (default: 70)
5. Filter to articles scoring below the threshold
6. Sort by score ascending (lowest freshness first)
7. Present as numbered list:

```
### Articles due for freshness review

1. [NVIDIA Spark Specs](wiki/topics/nvidia-spark.md) — score 42/100 (hot, sources 120d old, unverified 62d)
2. [CLI UX Patterns](wiki/concepts/cli-ux-patterns.md) — score 65/100 (warm, sources 105d old, unverified 105d)
3. [TCP/IP Fundamentals](wiki/references/tcp-ip.md) — score 94/100 (cold, stable — informational only)

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
