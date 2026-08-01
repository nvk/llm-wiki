---
description: "Find, catalog, deduplicate, and optionally inventory bounded sets of artifacts, examples, resources, memes, tools, entities, media, or other collectible things."
argument-hint: "\"<things to collect>\" [--type <kind>] [--scale tiny|small|medium|large|huge] [--limit <N>] [--media archive|thumbnail|reference] [--inventory preview|none|corpus|records] [--ingest-sources] [--dry-run] [--wiki <name>] [--local] [--include-archived]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*), Bash(mkdir:*), Bash(curl:*), Bash(shasum:*), Bash(file:*), Bash(stat:*), WebSearch, WebFetch, Agent
---

## Your task

Find and catalog a bounded set of "things" for the target wiki. This command is
for collectible objects and examples where the deliverable is a curated catalog:
memes, images, videos, quotes, tools, projects, products, examples, people,
venues, source candidates, and similar discoverable artifacts.

Treat collect outputs as a provenance-rich discovery layer for the LLM. They are
where the agent records "I found these things, with this context and confidence,
but I have not yet decided what they mean." Later workflows may promote selected
context pages into `raw/`, synthesize stable knowledge into `wiki/`, create
durable tracking records in `inventory/`, or index large media/data collections
in `datasets/`.

Collect is not the same as `/wiki:research` or `/wiki:ingest-collection`:

- Use `/wiki:research` when the user wants an answer, explanation, thesis, or
  synthesized wiki articles.
- Use `/wiki:ingest-collection` when the input is a structured upstream corpus
  such as a Git repo, MediaWiki dump/API, message archive, or Wayback CDX set.
- Use `/wiki:inventory` directly when the user already knows the records to
  track and no discovery/catalog pass is needed.
- Use `/wiki:collect` when the user says "find", "collect", "catalog",
  "curate", "gather", "make a list of", or "inventory all the examples of X."

Always be clear about boundedness. "All" means "all discovered within the
stated search strategy, quality threshold, and limit", not the entire internet.

## Resolve the wiki

Follow the standard resolution flow:

1. Read `$HOME/.config/llm-wiki/config.json`. If it has `hub_path`, expand
   leading `~` only and prefer that path; use `resolved_path` only as a fallback
   cache when the expanded `hub_path` is unavailable and `resolved_path` is
   initialized. If config has only `resolved_path`, use it. If the configured
   path can be statted but reading `wikis.json` or listing `topics/` fails with
   `Operation not permitted`, stop and ask the user to grant Full Disk
   Access/iCloud Drive access to the launcher; do not fall back to `~/wiki` or
   `resolved_path`. Do not write machine-specific `resolved_path` into shared
   configs.
2. If no config exists, read `$HOME/wiki/_index.md`. If it exists, use
   `$HOME/wiki` as HUB. If nothing is found, ask where to create the wiki.
3. Wiki location, first match: `--local` -> `.wiki/`; `--wiki <name>` ->
   `HUB/wikis.json` lookup with portable path resolution (`<HUB>`, `~`,
   absolute, or HUB-relative), falling back to `HUB/topics/<name>` if stale;
   current directory has `.wiki/` -> use it; otherwise use HUB.
4. Read `<wiki>/_index.md` to verify. If missing, stop with "No wiki found. Run
   `/wiki init` first."

Archive rule: collect operates on active topic wikis by default. If a named
target is archived, stop and ask the user to restore it or rerun with
`--include-archived`. When explicitly included, write only inside that archived
topic and label the result as archived.

Read `skills/wiki-manager/references/inventory.md` and
`skills/wiki-manager/references/research-infrastructure.md` before writing. Use
inventory as tracking state, not evidence.

## Parse arguments

- **Query**: the thing to collect, e.g. `"bitcoin memes"`, `"open-source LLM
  eval tools"`, `"companies using Nostr"`, or `"examples of SeedQR backup UX"`.
- **--type <kind>**: optional collection kind. Examples: `meme`, `image`,
  `video`, `tool`, `project`, `person`, `company`, `quote`, `paper`, `source`,
  `example`. If omitted, infer from the query.
- **--scale <scale>**: optional scale override. See Scale below.
- **--limit <N>**: maximum catalog rows. Defaults by scale. If the user asks for
  "all", still apply the scale limit unless they explicitly set a higher one.
- **--media archive|thumbnail|reference**:
  - `archive` default for media-bearing collections: download originals or
    rich media when a direct public media URL is available and the collection
    remains bounded.
  - `thumbnail`: cache small previews instead of originals when full originals
    are too heavy for the requested collection.
  - `reference`: opt out of binary downloads and store URLs plus metadata only.
- **--inventory preview|none|corpus|records**:
  - `preview` default: suggest inventory shape but do not create records unless
    the user's wording explicitly asked to inventory the findings.
  - `none`: only write the collection output.
  - `corpus`: create one `inventory/corpora/` record pointing at the collection
    output.
  - `records`: create one inventory record per collected item when the count is
    small enough to remain useful.
- **--ingest-sources**: ingest strong supporting pages as raw sources after the
  catalog is built. Do not copy binary media into raw; raw is source text.
- **--dry-run**: show the search strategy, candidate schema, scale, media
  policy, and inventory fit without writing files.
- **--include-archived**: explicitly allow writes inside an archived target.

## Scale

Define scale by operational cost, not only row count. Use the maximum pressure
from candidate count, boundedness, payload weight, provenance burden, volatility,
and inventory usefulness.

| Scale | Rows | Source Shape | Default Behavior |
|-------|------|--------------|------------------|
| `tiny` | 1-3 | Known items | Skip collect; use ingest, query, or inventory directly |
| `small` | 4-25 | Discoverable with normal search | Write catalog output; per-item inventory allowed |
| `medium` | 26-100 | Open web or mixed sources | Write catalog output; inventory as one corpus record by default |
| `large` | 101-500 | Many candidates or unstable sources | Dry-run first; require confirmation; no per-item inventory by default |
| `huge` | 501+ | Structured corpus, dataset, archive, or large media set | Use dataset or ingest-collection, not collect |

For open-web media such as "bitcoin memes", default to `medium` even if the
initial target list is modest: provenance is messy, aliases are common, media
rights are unclear, and duplicates/reposts are expected.

Scale controls writes:

- `tiny`: answer directly or route to ingest/inventory.
- `small`: catalog plus optional per-item inventory.
- `medium`: catalog plus one corpus inventory record by default.
- `large`: preview first and ask before writing.
- `huge`: redirect to dataset manifest or ingest-collection.

## Fit check

Start with a one-sentence fit judgment:

- **Appropriate for collect**: the user wants discovery plus a catalog of many
  objects, examples, assets, or entities.
- **Too source-like**: a bounded upstream corpus should be `ingest-collection`.
- **Too analytical**: a question or thesis should be `research` or `query`.
- **Too operational**: known tracking records should be `inventory`.
- **Too large**: hundreds or thousands of row-like items should become one
  corpus inventory record plus a dataset manifest or collection ingest.

For ambiguous cases, state the recommended workflow before doing work.

## Topic naming for collection families

When creating or suggesting a topic wiki for a collection family, prefer a
kind-first slug: `<kind>-<subject>`. This keeps related collections grouped as
the wiki grows, for example `memes-bitcoin`, `memes-ethereum`,
`tools-bitcoin`, or `examples-seedqr`. Use a subject-first slug only when the
subject is clearly the primary research area and the collection is just one
artifact inside that broader topic.

## Collection flow

1. **Scope the catalog**
   - Infer collection kind, scale, inclusion criteria, exclusion criteria, media
     policy, and default tags.
   - Define 4-8 search queries that cover canonical names, aliases, platforms,
     filenames, and historical terms.
   - Note likely blind spots such as deleted social posts, paywalled archives,
     platform search limitations, binary-only media, and unclear rights.

2. **Discover candidates**
   - Use WebSearch for each query. Use WebFetch only for promising result pages.
   - For web artifacts like memes, prefer pages that preserve provenance:
     original posts, archived originals, creator pages, official pages, GitHub
     repos, museum/library entries, Know Your Meme-style references, and
     well-cited retrospectives.
   - Avoid SEO listicles unless they contain unique source links.
   - Do not recursively crawl the open web. Follow only direct source links
     needed to verify a candidate.

3. **Extract catalog rows**
   For each candidate, capture:
   - `title`: canonical display name selected for this catalog.
   - `aliases`: names observed in captions, filenames, source pages, reposts,
     communities, or common usage.
   - `type`
   - `canonical_url`
   - `media_url` for binary media, when relevant.
   - `source_url` if different from canonical.
   - `source_title` for the page/post title where it was found.
   - `media_filename` when visible.
   - `origin_platform` or publisher when known.
   - `creator` and date when known.
   - `description`
   - `evidence` for why it belongs in the collection.
   - `found_in_context`: one or more contextual sightings. See below.
   - `provenance_confidence`: high, medium, or low.
   - `rights_or_license` when visible, else `unknown`.
   - `media_format`, `media_cached`, `local_media_path`, `media_bytes`,
     `sha256`, `perceptual_hash`, `downloaded_at`, and `download_status` for
     media when available.
   - tags
   - next action, if it should be tracked.

4. **Record found-in-context provenance**
   `found_in_context` is first-class provenance. A naked media URL proves very
   little; a page, thread, post, caption, archive snapshot, or retrospective
   gives the item meaning.

   Use a list because the same artifact often has multiple sightings:
   ```yaml
   found_in_context:
     - context_url: "https://example.com/thread-or-page"
       context_title: "Context page title"
       platform: "Bitcointalk"
       found_at: YYYY-MM-DD
       collector_query: "bitcoin magic internet money wizard meme"
       role: original|near-original|repost|reference|retrospective|usage-example|archive-snapshot|unclear
       surrounding_label: "Magic Internet Money"
       context_summary: "Page presents the image as a Bitcoin meme."
       provenance_confidence: medium
   ```

   Rank provenance roughly as: original post/page with date and creator,
   archived original or near-original, known reference page, repost with clear
   context, then standalone media URL with no context.

5. **Download binaries and media**
   - For media-bearing collections, default to `--media archive`: download each
     candidate's direct public `media_url` when the payload is bounded and the
     URL does not require login, paywall bypass, anti-hotlink circumvention, or
     scraping around access controls.
   - Use defensive download settings: set connection and total timeouts, cap
     file size before writing large batches, verify `Content-Type` against the
     expected media family, and retry transient failures sparingly. If a host
     hangs on IPv6, retry with IPv4 (`curl -4`) before marking the row failed.
   - Never put binaries in `raw/`; raw is for immutable source text and source
     pages. Cached binaries belong under `output/assets/collect-<query-slug>/`
     or the relevant `output/projects/<slug>/assets/` folder.
   - Use stable, sanitized filenames such as
     `<row-number>-<item-slug>.<ext>`. Keep originals under `originals/` for
     `archive`, previews under `thumbnails/` for `thumbnail`, and write an
     `assets-manifest.md` file in the asset folder.
   - Record `local_media_path` relative to the wiki root, `media_cached: true`,
     `media_bytes`, `media_format`, `sha256`, `downloaded_at`, and visible
     rights/license in the collection output. If a download fails or is skipped,
     keep the row and record `download_status` plus the reason.
   - Catalog media URLs, context pages, aliases, hashes when available, rights,
     and media metadata even when downloads are skipped or `--media reference`
     is used.
   - For hundreds of media items or large binary payloads, create a
     `datasets/<slug>/MANIFEST.md` and/or ask before bulk downloading rather
     than flooding `output/` or `inventory/`.

6. **Deduplicate**
   - Merge candidates with the same canonical URL, same source/media URL, same
     title/alias plus creator/date, or clear repost/rehost relationships.
   - For media, use filenames, dimensions, checksums, perceptual hashes, and
     found-in-context evidence when available.
   - Keep alternate URLs and aliases in notes. Prefer the original or most
     authoritative URL as canonical.

7. **Rank**
   - Prioritize provenance, relevance, notability, usefulness to the wiki, and
     confidence.
   - For memes and cultural artifacts, popularity claims need sources;
     otherwise label them as apparent or anecdotal.

8. **Write the collection output**
   Unless `--dry-run`, save to:
   `output/collect-<query-slug>-YYYY-MM-DD.md`

   Use frontmatter:
   ```yaml
   ---
   title: "<Title> Collection"
   type: collection
   generated: YYYY-MM-DD
   query: "<original query>"
   collect_kind: "<kind>"
   scale: small|medium|large
   limit: N
   media_policy: archive|thumbnail|reference
   media_assets: output/assets/collect-<query-slug>/
   media_downloaded: N
   media_failed: M
   sources:
     - "https://example.com/source"
   tags: [collect, tag1, tag2]
   summary: "Catalog of N collected <kind> items for <topic>."
   ---
   ```

   Body structure:
   - `# <Title> Collection`
   - `## Why This Collection Matters To The Wiki`
   - `## Scope`
   - `## Search Strategy`
   - `## Catalog` with a compact table
   - `## Media And Binary Handling`
   - `## Notable Gaps`
   - `## Inventory Recommendation`
   - `## Sources Checked`

9. **Update output indexes**
   - Rebuild or update `output/_index.md`.
   - Update the master `_index.md` output count and recent changes.
   - Append to `log.md`:
     `## [YYYY-MM-DD] collect | <query>: N items cataloged, inventory <mode>`

10. **Handle inventory**
    Inventory is optional tracking state after the collection output exists.

    - If the user did not ask for inventory and `--inventory preview` is active,
      include a sample inventory shape in the output and stop.
    - If the user asked to inventory the findings, or set `--inventory corpus`,
      create one `inventory/corpora/<slug>.md` record when the collection is
      medium/large, unstable, media-heavy, or mainly a source pool.
    - If the user asked to inventory the findings, or set `--inventory records`,
      create per-item records only when the list is small enough to stay useful
      in chat, normally 25 records or fewer. For larger lists, create one corpus
      record and include a sample of per-item records instead of flooding
      inventory.
    - Use `kind: artifact` for cultural or media artifacts such as memes,
      `kind: item` for tools/products/assets, `kind: entity` for people/orgs,
      and `kind: corpus` for a source pool.
    - Every inventory record created from collect should include `origin:
      output/collect-<query-slug>-YYYY-MM-DD.md` and `sources:` pointing at the
      output plus the item's canonical URL or context URL.
    - Rebuild affected inventory indexes and append one inventory log line:
      `## [YYYY-MM-DD] inventory | collect linked <query>: N records`

11. **Optional raw ingestion**
    If `--ingest-sources` is set, ingest only source pages whose text materially
    supports the wiki. Do not ingest every candidate row by default, and do not
    copy binary assets into raw sources.

## Item schema example

```yaml
title: "Magic Internet Money Wizard"
aliases:
  - "Bitcoin Wizard"
  - "Magic Internet Money"
  - "Internet Money Wizard"
  - "Buy Bitcoin Wizard"
type: meme-image
canonical_url: null
media_url: "https://example.com/wizard.png"
source_url: "https://example.com/context-page"
source_title: "Context page title"
media_filename: "wizard.png"
origin_platform: "Reddit"
creator: unknown
first_seen: unknown
description: "Image macro associated with Bitcoin promotion."
evidence: "Found in multiple Bitcoin meme retrospectives and source-context pages."
found_in_context:
  - context_url: "https://example.com/context-page"
    context_title: "Context page title"
    platform: "Reddit"
    found_at: YYYY-MM-DD
    collector_query: "bitcoin magic internet money wizard meme"
    role: reference
    surrounding_label: "Magic Internet Money"
    context_summary: "Page presents the image as a Bitcoin meme."
    provenance_confidence: medium
rights_or_license: unknown
media_format: image/png
media_cached: true
local_media_path: output/assets/collect-bitcoin-memes/originals/01-magic-internet-money-wizard.png
media_bytes: 123456
sha256: "<sha256>"
perceptual_hash: null
downloaded_at: YYYY-MM-DD
download_status: downloaded
provenance_confidence: medium
tags: [bitcoin, meme, collect]
next_action: "Find original post or archived original."
```

## Inventory record templates

Per-artifact record:

```yaml
---
title: "<Collected Item>"
kind: artifact
status: proposed
priority: p3
created: YYYY-MM-DD
updated: YYYY-MM-DD
last_checked: YYYY-MM-DD
origin: output/collect-<query-slug>-YYYY-MM-DD.md
sources:
  - output/collect-<query-slug>-YYYY-MM-DD.md
  - "https://example.com/context-or-canonical-item"
tags: [collect, <topic>, <kind>]
confidence: medium
summary: "Collected <kind> item discovered during <query> collection."
---
```

Corpus record:

```yaml
---
title: "<Query> Collection"
kind: corpus
status: proposed
priority: p2
created: YYYY-MM-DD
updated: YYYY-MM-DD
last_checked: YYYY-MM-DD
next_action: "Review collection output and decide which items deserve individual tracking or source ingestion."
origin: output/collect-<query-slug>-YYYY-MM-DD.md
sources:
  - output/collect-<query-slug>-YYYY-MM-DD.md
tags: [collect, <topic>, corpus]
confidence: medium
summary: "Collected catalog for <query>, tracked as one corpus to avoid flooding inventory."
---
```

## Report

Always report:

- Wiki root path
- Output path, unless `--dry-run`
- Scale and media policy
- Media assets path and download counts, when applicable
- Search queries used
- Candidate count before and after deduplication
- Inventory mode and records created, if any
- Gaps and follow-up searches that would improve coverage
