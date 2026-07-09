# Librarian Reference

Content-level wiki maintenance: staleness detection, quality scoring, factual
verification, semantic coherence, deduplication, and proposal-only topic schema
advice. This reference defines the scoring algorithms, report formats, and
operational protocols for `/wiki:librarian`.

## Design Principles

1. **Score then act.** The librarian produces scores and reports. It never modifies wiki content during a scan. Write operations (fix, auto-fix) are separate commands requiring explicit confirmation.
2. **Conservative by default.** When uncertain, flag for human review rather than auto-classifying as clean. Lean toward false positives over false negatives.
3. **Checkpoint everything.** After scoring each article, write the result to `.librarian/checkpoint.json`. If the session drops, the next invocation resumes from where it left off.
4. **Two-tier escalation.** Quick metadata-only scan first (cheap). Deep content read only for articles that score below threshold or have `volatility: hot`. Token cost scales with problem density, not wiki size.
5. **Machine-readable first.** `.librarian/scan-results.json` is the source of truth. `REPORT.md` is rendered from it. Other skills read the JSON.
6. **Default schema, explicit adoption.** New topic wikis have a human-owned
   advisory `schema.md`. Librarian may propose topic-specific improvements, but
   never rewrites `schema.md` during a scan. Applying proposals and switching to
   strict mode are explicit user decisions.

## Staleness Scoring (Pass 1)

Composite score 0-100 across four dimensions, each contributing 0-25 points. Uses the same four dimensions as the freshness design in `wiki-structure.md`, applied per-article.

### Dimensions

| Dimension | Measures | Source Field | Computation |
|-----------|----------|-------------|-------------|
| Source freshness | Age of raw sources | `sources:` → each raw file's `ingested:` date | Average days since ingestion across all sources |
| Verification recency | Last human confirmation | `verified:` date | Days since verified |
| Compilation recency | Article currency | `updated:` date | Days since updated |
| Source chain integrity | Referenced sources exist | `sources:` entries | Percentage of sources that resolve to actual files |

Resolve `sources:` entries with the Source Reference Resolution protocol in
`wiki-structure.md`. A source entry is a complete YAML scalar/path and may
contain spaces. Do not split on whitespace, and do not classify a source as
missing until exact path resolution and the slug fallback have both failed.
Ambiguous slug fallback matches count as unresolved for scoring and should be
listed separately in the report factors.

### Decay Curves by Volatility

Each dimension's raw day-count is converted to a 0-25 score using exponential decay scaled by the article's `volatility` tier:

| Volatility | Half-life (days) | Effect |
|------------|-----------------|--------|
| `hot` | 30 | Score decays quickly — 60-day-old hot article scores ~50% |
| `warm` | 90 | Moderate decay — 90-day-old warm article scores ~50% |
| `cold` | 365 | Slow decay — cold articles stay fresh for a year |

**Formula per dimension** (except source chain integrity):

```
dimension_score = 25 * 0.5^(days_old / half_life)
```

**Source chain integrity** (no decay — binary per source):

```
integrity_score = 25 * (resolved_sources / total_sources)
```

**Composite staleness score**:

```
staleness_score = source_freshness + verification_recency + compilation_recency + integrity
```

Range: 0 (completely stale) to 100 (perfectly fresh).

### Missing Fields

- Missing `volatility`: treat as `warm` (safe default, matches C15 auto-fix)
- Missing `verified`: treat as never verified — verification_recency = 0
- Missing `updated`: fall back to `created` date
- Missing `sources`: integrity = 0 (no sources to verify)

### `compiled-from: conversation` Exemption

Articles whose evidence is the conversation that authored them — not fetchable raw files — set `compiled-from: conversation` in frontmatter (see `wiki-structure.md` schema and `linting.md` C18). For these articles:

- Skip the **source freshness** dimension (no `sources:` to age) — set its contribution to 0 of 0 (excluded, not zero-of-25).
- Skip the **source chain integrity** dimension (no `sources:` to resolve) — set its contribution to 0 of 0.
- Compute the **verification recency** and **compilation recency** dimensions as usual.
- Re-base the composite to a 50-point scale (verification + compilation, each 0-25), then multiply by 2 to land on the same 0-100 score range as standard articles.

Effect: a `compiled-from: conversation` article verified within its volatility's half-life scores ~95-100. A neglected one decays at the same rate as any other article on the verification/compilation dimensions. The article is no longer permanently capped at 50 by missing sources.

Articles with `compiled-from: mixed` are scored using the standard four-dimension formula — `mixed` means some sources exist, so integrity is meaningful.

### Staleness Threshold

Read `freshness_threshold` from the wiki's `config.md` (default: 70). Articles scoring below this threshold are flagged.

## Quality Scoring (Pass 5)

Four dimensions, each scored 1-5. Composite quality score is the average, mapped to 0-100.

### Dimensions

| Dimension | 1 (Stub) | 3 (Adequate) | 5 (Featured) |
|-----------|----------|-------------|--------------|
| **Depth** | Single paragraph, no structure | Multiple sections, covers key aspects | Comprehensive treatment with nuance, examples, and edge cases |
| **Source quality** | No sources or single low-confidence source | 2-3 sources, mixed confidence | 4+ high-confidence sources that corroborate |
| **Coherence** | Disjointed, no logical flow | Readable structure, minor gaps | Clear narrative arc, smooth transitions, no logical gaps |
| **Utility** | Trivial or obvious information | Useful for understanding the topic | Actionable for decision-making, includes tradeoffs and recommendations |

### Scoring Protocol

**Tier 1 (metadata-only, all articles)**:
- Source quality: count sources, read their `confidence:` fields. Score derivable without reading article body.
- Depth (proxy): word count + heading count from file stats. <200 words or 0 headings = stub (1-2). >1000 words + 3+ headings = likely good (4-5).

**Tier 2 (deep read, escalated articles only)**:
- Read the full article body.
- Score coherence and utility by analyzing the content.
- Refine the depth and source quality scores from Tier 1.
- Escalation triggers: staleness score < 70, volatility = hot, or Tier 1 depth proxy = 1-2.

### Quality Flags

In addition to numeric scores, tag articles with specific quality flags:

| Flag | Trigger |
|------|---------|
| `thin-coverage` | Depth score 1-2 |
| `single-source` | Only one source in `sources:` |
| `low-confidence-sources` | Average source confidence below medium |
| `no-see-also` | Zero "See Also" cross-references |
| `stale` | Staleness score below threshold |
| `unverified` | Missing `verified:` field |

### Composite Quality Score

```
quality_score = ((depth + source_quality + coherence + utility) / 4) * 20
```

Range: 20 (worst possible — all 1s) to 100 (all 5s). Articles below 50 are surfaced for review.

## Topic-Guide Conventions Pass

The conventions pass helps topic wikis converge on a local vocabulary and helps
older wikis adopt the default `schema.md` topic guide without content rewrites.
`schema.md` is a human-owned topic guide, not a database schema.

### Canonical Files

- Human-owned topic guide: `<wiki-root>/schema.md` (default for new wikis)
- Optional derived cache: `<wiki-root>/.librarian/schema.json`
- Proposal output:
  `output/schema-proposal-<topic>-YYYY-MM-DD.md`

`schema.md` may define topic-local entity types, relationship verbs, article
subtypes, source conventions, and inventory/dataset boundaries. It must not
redefine global llm-wiki primitives such as raw source types, article
categories, inventory kinds, or required frontmatter.

### Adoption States

| State | Meaning | Behavior |
|-------|---------|----------|
| `missing` | Older wiki has no `schema.md` | Valid; report a non-blocking adoption action |
| `proposed` | Librarian wrote a proposal output | Human reviews before adoption |
| `advisory` | `schema.md` exists | Report mismatches as suggestions |
| `strict` | Explicit opt-in in `schema.md` | Warn on violations; never auto-rewrite content |

### Proposal Trigger

Recommend a schema proposal when a topic is active and has roughly 10+ compiled
articles, or when indexes reveal repeated category/link/source ambiguity. For
small or one-off wikis without `schema.md`, recommend the default adoption
helper (`llm-wiki schema adopt` or `llm-wiki lint --fix`) instead of
writing a large proposal.

### Proposal Sources

Derive proposals from observed reality:

- article titles, aliases, tags, and categories;
- See Also links and markdown link neighborhoods;
- raw source types, collection manifests, and source tags;
- inventory entities/corpora/items and dataset manifests;
- recurring output/project prefixes.

### Scan Behavior

When `conventions` (or legacy `schema`) is included in `--passes`, add a
`schema` object to `scan-results.json`:

```json
{
  "state": "proposed",
  "migration": "proposal-written",
  "proposal": "output/schema-proposal-meta-llm-wiki-2026-07-06.md",
  "recommendations": [
    "Adopt entity types for commands, workflows, runtimes, and artifacts",
    "Use relationship verbs such as depends-on, supersedes, implements, cites"
  ]
}
```

Render the same information in `REPORT.md` under `## Schema Advice`.

The scan must not create or rewrite `schema.md`; applying a proposal is a
separate, explicit user decision. If no schema exists and no proposal is useful,
render an adoption recommendation instead:

```json
{
  "state": "missing",
  "migration": "default-topic-guide-recommended",
  "recommendations": [
    "Run llm-wiki schema adopt to add an advisory starter topic guide",
    "Keep schema_state: advisory until librarian reports are low-noise"
  ]
}
```

## Checkpoint Protocol

The `.librarian/` directory lives inside each topic wiki (e.g., `~/wiki/topics/meta-llm-wiki/.librarian/`). Created on first scan.

### checkpoint.json

Written after each article is scored. If the session drops, the next `scan` or `scan --resume` reads this file and skips already-scored articles.

```json
{
  "scan_id": "2026-04-22T10:30:00Z",
  "wiki": "meta-llm-wiki",
  "passes": ["staleness", "quality"],
  "scope": "full",
  "threshold": 70,
  "completed": ["wiki/concepts/article-a.md", "wiki/concepts/article-b.md"],
  "pending": ["wiki/topics/article-c.md"],
  "results": {
    "wiki/concepts/article-a.md": {
      "staleness": { "score": 92, "factors": { "source_freshness": 23, "verification": 24, "compilation": 22, "integrity": 23 } },
      "quality": { "score": 85, "dimensions": { "depth": 4, "source_quality": 5, "coherence": 4, "utility": 4 }, "flags": [] },
      "tier": 1,
      "scanned_at": "2026-04-22T10:31:00Z"
    }
  }
}
```

**Atomic writes**: Write to `.librarian/.checkpoint.tmp`, then rename to `checkpoint.json`. Incomplete writes from crashes are detected (missing or unparseable tmp file) and the last article is rescanned.

**Clearing**: Checkpoint is deleted when a scan completes successfully and `scan-results.json` is written.

### scan-results.json

The complete scan output. Source of truth for other skills.

```json
{
  "scan_id": "2026-04-22T10:30:00Z",
  "wiki": "meta-llm-wiki",
  "completed_at": "2026-04-22T10:45:00Z",
  "passes": ["staleness", "quality"],
  "threshold": 70,
  "summary": {
    "articles_scanned": 29,
    "stale_count": 4,
    "low_quality_count": 2,
    "avg_staleness": 78,
    "avg_quality": 72,
    "worst_staleness": { "article": "wiki/topics/some-topic.md", "score": 31 },
    "worst_quality": { "article": "wiki/concepts/some-concept.md", "score": 42 }
  },
  "articles": {
    "wiki/concepts/article-a.md": {
      "staleness": { "score": 92, "factors": { "source_freshness": 23, "verification": 24, "compilation": 22, "integrity": 23 } },
      "quality": { "score": 85, "dimensions": { "depth": 4, "source_quality": 5, "coherence": 4, "utility": 4 }, "flags": [] },
      "tier": 1
    }
  },
  "schema": {
    "state": "absent|proposed|advisory|strict",
    "proposal": "output/schema-proposal-<topic>-YYYY-MM-DD.md",
    "recommendations": []
  }
}
```

### REPORT.md

Human-readable report generated from `scan-results.json`. Format:

```markdown
# Librarian Report — YYYY-MM-DD

> Scanned N articles in <wiki-name>. Passes: staleness, quality.

## Summary

| Metric | Value |
|--------|-------|
| Articles scanned | N |
| Below staleness threshold | N |
| Low quality (< 50) | N |
| Average staleness | N/100 |
| Average quality | N/100 |

## Stale Articles (staleness < threshold)

| Article | Score | Top Factor | Recommendation |
|---------|-------|-----------|----------------|
| [Title](path) | 31/100 | sources 180d old | refresh |
| [Title](path) | 45/100 | unverified 120d | verify |

## Low Quality Articles (quality < 50)

| Article | Score | Flags | Recommendation |
|---------|-------|-------|----------------|
| [Title](path) | 42/100 | thin-coverage, single-source | expand and add sources |

## Schema Advice

| State | Proposal | Recommendation |
|-------|----------|----------------|
| proposed | [Schema Proposal](../output/schema-proposal-topic-YYYY-MM-DD.md) | Review and explicitly apply if useful |

## All Articles (sorted by combined score)

| Article | Staleness | Quality | Flags |
|---------|-----------|---------|-------|
| ... | ... | ... | ... |
```

### log.md

Append-only librarian activity log at `.librarian/log.md`:

```
## [YYYY-MM-DD] scan | N articles, M stale, K low-quality (passes: staleness, quality)
## [YYYY-MM-DD] scan --article wiki/concepts/foo.md | staleness 45, quality 72
```

## Boundary with Other Commands

| Command | Responsibility | Librarian Does NOT |
|---------|---------------|-------------------|
| `lint` | Structure: broken links, missing indexes, frontmatter schema, file placement | Lint's territory — librarian skips |
| `lint --deep` (C7) | Quick spot-check: a few web searches for obvious staleness | Lightweight — librarian goes deeper |
| `refresh` | Re-fetch sources, compare changes, offer recompilation | Librarian flags, then delegates to refresh |
| `compile` | Transform raw sources into wiki articles | Librarian reviews compiled output, never compiles |

When the librarian flags an article as stale and the user confirms, it delegates to the refresh protocol in `commands/refresh.md` for that article.
