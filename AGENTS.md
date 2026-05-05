# LLM Wiki — Agent Instructions

> This is an "idea file" in the spirit of [Karpathy's LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f). Paste it into any LLM agent (OpenAI Codex, Claude Code, OpenCode, Gemini Code Assist, or similar) and it will build and manage a wiki for you. The agent customizes the specifics; this file communicates the system.

> **Editing the llm-wiki repo itself?** This file is the portable wiki *protocol* for end users. The dev contract for the plugin codebase (testing, sync workflow, project structure, symlink invariant) lives in [`CLAUDE.md`](CLAUDE.md) — read it in addition to this file. Both Claude Code and Codex agents working on the repo should treat `CLAUDE.md` as the source of truth for repo-level workflow.

## What This Is

An LLM-compiled knowledge base. You (the LLM agent) are both the compiler and the query engine. Raw source documents are ingested, then incrementally compiled into a wiki of interconnected markdown articles. The human rarely edits the wiki directly — that's your domain.

**The metaphor**: raw sources are source code, you are the compiler, the wiki is the executable.

## Architecture

### Hub Path

Defaults to `~/wiki/`. Optionally configured via `~/.config/llm-wiki/config.json`:

```json
{ "hub_path": "~/Library/Mobile Documents/com~apple~CloudDocs/wiki" }
```

If the config exists, use `hub_path` (expand `~`) instead of `~/wiki/` everywhere below. Store as **HUB**. Use `/wiki config hub-path <path>` to set it up, or create the JSON manually.

### Hub (~/wiki/)

The hub is lightweight — NO content, just a registry.

```
~/wiki/                         # or custom path from config.json
├── wikis.json          # Registry of all topic wikis
├── _index.md           # Lists topic wikis with stats
├── log.md              # Global activity log
└── topics/
    ├── nutrition/      # Each topic is a full, isolated wiki
    ├── robotics/
    └── ...
```

### Topic Wiki (~/wiki/topics/<name>/)

All content lives here. One topic per wiki. Isolated indexes, focused queries.

```
~/wiki/topics/<name>/
├── .obsidian/                     # Obsidian vault config (optional)
├── .librarian/                    # Optional: wiki-only maintenance reports
├── .audit/                        # Optional: umbrella audit reports
├── .research-session.json         # Ephemeral: live recovery for --min-time research (deleted on completion)
├── .thesis-session.json           # Ephemeral: live recovery for --mode thesis (deleted on completion)
├── .session-events.jsonl          # Durable: append-only event log for replayable provenance
├── .session-checkpoint.json       # Durable: latest run summary for resume briefings + audit classification
├── _index.md                      # Master index: stats, navigation, recent changes
├── config.md                      # Title, scope, conventions
├── log.md                         # Activity log for this topic
├── inbox/                         # Drop zone — user dumps files here
│   └── .processed/
├── raw/                           # Immutable source material
│   ├── _index.md
│   ├── articles/*.md
│   ├── papers/*.md
│   ├── repos/*.md
│   ├── notes/*.md
│   └── data/*.md
├── wiki/                          # Compiled articles (LLM-maintained)
│   ├── _index.md
│   ├── concepts/*.md              # Bounded ideas
│   ├── topics/*.md                # Broad themes
│   ├── references/*.md            # Curated collections
│   └── theses/*.md                # Thesis investigations with verdicts
└── output/                        # Generated artifacts
    ├── _index.md
    └── *.md
```

### Local Wiki (.wiki/)

Same structure as a topic wiki but at `<project>/.wiki/`. Add `.wiki/` to `.gitignore`.

## Core Principles

1. **One topic, one wiki.** Never mix unrelated topics. The hub is just a registry.
2. **Indexes are navigation.** Every directory has `_index.md` with a contents table. Read indexes first, never scan blindly. Keep them current.
3. **Raw is immutable.** Once ingested, sources are never modified. All synthesis happens in `wiki/`.
4. **Articles are synthesized, not copied.** Draw from multiple sources, contextualize, connect. Think textbook, not clipboard.
5. **Dual-linking.** Every cross-reference uses both formats on the same line: `[[slug|Name]] ([Name](../category/slug.md))`. Obsidian reads the wikilink, the agent reads the markdown link, GitHub renders it. Not locked into any tool.
6. **Incremental by default.** Only compile new sources unless explicitly asked for full recompile.
7. **Honest gaps.** If the wiki doesn't have the answer, say so. Suggest what to ingest.
8. **Multi-wiki peek.** When querying, answer from the target wiki, then peek at sibling wiki `_index.md` files for overlap.
9. **Confidence scoring.** Articles get `confidence: high|medium|low` in frontmatter based on source quality.
10. **Activity log.** Append every operation to `log.md`. Format: `## [YYYY-MM-DD] operation | Description`. Never edit existing entries.

## File Formats

### _index.md (every directory)

```markdown
# [Directory Name] Index

> [One-line description]

Last updated: YYYY-MM-DD

## Contents

| File | Summary | Tags | Updated |
|------|---------|------|---------|
| [file.md](file.md) | One-sentence summary | tag1, tag2 | YYYY-MM-DD |

## Categories

- **category**: file1.md, file2.md

## Recent Changes

- YYYY-MM-DD: Description
```

Master `_index.md` additionally has Statistics and Quick Navigation sections.

### Raw Source (raw/)

```yaml
---
title: "Title"
source: "URL or filepath or MANUAL"
type: articles|papers|repos|notes|data
ingested: YYYY-MM-DD
tags: [tag1, tag2]
summary: "2-3 sentence summary"
---
```

### Wiki Article (wiki/)

```yaml
---
title: "Article Title"
category: concept|topic|reference
sources: [raw/type/file1.md, raw/type/file2.md]
created: YYYY-MM-DD
updated: YYYY-MM-DD
tags: [tag1, tag2]
aliases: [alternate names]
confidence: high|medium|low
summary: "2-3 sentence summary"
---
```

Body includes abstract, sections, `## See Also` (dual-links, bidirectional), `## Sources` (links to raw/).

### Source Reference Resolution

Treat `sources:` entries as exact paths first, not whitespace-delimited slugs.
Parse them as YAML list scalars; if falling back to line parsing, preserve the
complete value after `- ` and strip only matching wrapping quotes. Resolve
`raw/...`, `wiki/...`, and `output/...` from the wiki root; resolve `../...`
relative to the file that owns the `sources:` field. If exact resolution fails,
slugify both the requested value and raw-file stems (lowercase, whitespace or
underscores to hyphens, remove other special characters, collapse hyphens; also
try raw stems with a leading `YYYY-MM-DD-` stripped) and accept only a single
match. Report zero matches as unresolved and multiple matches as ambiguous.
Never rename raw files during resolution. When linking to raw filenames with
spaces in markdown, use angle-bracket destinations:
`[Title](<../../raw/articles/File Name.md>)`.

### wikis.json

```json
{
  "default": "~/wiki",
  "wikis": {
    "hub": { "path": "~/wiki", "description": "Hub" },
    "<name>": { "path": "~/wiki/topics/<name>", "description": "..." }
  },
  "local_wikis": []
}
```

### log.md

```
## [YYYY-MM-DD] operation | Description
```

Operations: `init`, `ingest`, `ingest-collection`, `compile`, `query`, `lint`, `research`, `thesis`, `output`, `assess`, `refresh`, `librarian`, `audit`, `plan`, `project`, `ll`

## Operations

### Init

Create a topic wiki. Always require a topic name. If the hub doesn't exist, create it first (just wikis.json + _index.md + log.md + topics/). Create the full topic wiki structure, empty _index.md files, config.md, log.md, and optionally .obsidian/ vault config.

### Ingest

Convert external material into a raw source file.

- **URLs**: Fetch content, extract title/author/date/text, write to `raw/articles/` or `raw/papers/`; download PDF URLs and run PDF extraction
- **Files**: Read directly, preserve formatting; convert PDFs to markdown when possible
- **Text**: User provides quoted text, write to `raw/notes/`
- **Inbox**: Scan `inbox/` for dumped files, process each by type, move to `inbox/.processed/`

Auto-detect type: arxiv/scholar/PDF papers → papers, github → repos, .csv/.json → data, everything else → articles.

PDFs are single-source ingests. Try `pdftotext -layout` only if local poppler is
working and produces non-trivial text; otherwise use a temporary Python venv
with a PDF library such as `pypdf` or `pymupdf`. Preserve page boundaries when
available. If the PDF is image-only and no OCR path is available, write a
metadata stub with `extraction_status: ocr-needed` rather than inventing text.

**Auto-classify** (when no `--wiki` specified): After fetching content, match against topic wiki scopes. Single items get a numbered choice (pick wiki, create new, or skip). Batch/inbox mode presents a classification table for bulk routing. Skipped when `--wiki` or `--local` is explicit.

Slug: `YYYY-MM-DD-descriptive-slug.md`. Update all indexes after each ingestion. If 5+ uncompiled sources, suggest compilation.

### Ingest Collection

Bulk-ingest bounded upstream corpora without turning them directly into compiled
wiki articles. Use this for Git document repositories, BIP-style proposal sets,
MediaWiki XML dumps/API sites, CSV/JSON message archives, and Wayback CDX
snapshot sets. Never recursively crawl HTML; use structured upstream
interfaces.

Adapters:
- **git**: clone shallowly or read a local repo; inventory text files with blob
  SHAs and HEAD commit. For BIP-style repos, prioritize `bip-####.mediawiki`
  and `bip-####.md`, parse proposal headers, and store each proposal as a child
  raw source.
- **mediawiki-dump**: read official `.xml`, `.xml.bz2`, or `.xml.gz` dumps with
  streaming XML parsing; default to namespace 0; skip redirects and non-content
  namespaces unless explicitly included.
- **mediawiki-api**: use `api.php` with `allpages` and `revisions` for targeted
  imports or dumpless sites; follow continuation tokens and respect throttling.
- **csv-messages**: parse `.csv`, `.tsv`, `.json`, or `.jsonl` message archives
  with Python stdlib; infer id/date/author/subject/body fields; write one raw
  markdown source per message, usually under `raw/notes/`.
- **wayback-cdx**: use Internet Archive CDX as the bounded inventory; fetch
  selected captures with `id_` replay URLs; run readability-to-markdown; write
  one raw article per readable snapshot.

Every collection import writes a manifest to `raw/repos/` tagged
`collection-manifest`, plus one immutable child source per upstream page/spec in
`raw/articles/` unless another type is more appropriate. Child frontmatter may
include `collection`, `adapter`, `upstream_id`, `upstream_type`, `revision`,
`sha`, `canonical_url`, `content_format`, `license`, `authors`, `categories`,
`outlinks`, `fetched`, and adapter-specific provenance such as `message_id`,
`row_number`, `wayback_timestamp`, or `wayback_digest`. Deduplicate by
`collection + upstream_id + revision/sha` or the adapter's stable row/snapshot
key; if upstream content changes, write a new raw source instead of overwriting
the old one.

Compile collections selectively: synthesize concepts, topics, timelines,
glossaries, standards families, and reference indexes. Do not create one
compiled wiki article per upstream page by default. For BIPs, publication is
provenance for proposal text, not proof of adoption or consensus. For community
wikis, default confidence to medium unless corroborated by stronger sources.

### Compile

Transform raw sources into wiki articles. Incremental by default (only new sources).

1. Survey: read indexes, identify uncompiled sources
2. Extract: key concepts, facts, relationships from each source
3. Map: which concepts need new articles vs updates to existing
4. Classify: concept (bounded idea), topic (broad theme), reference (curated list)
5. Write: synthesized articles with dual-links, frontmatter, confidence scores, aliases
6. Bidirectional links: if A links to B, ensure B links to A
7. Update all indexes

### Query

Answer questions from wiki content only. Three depths:

- **Quick**: Read indexes only. Fastest.
- **Standard** (default): Read relevant articles + full-text search. Follow See Also links.
- **Deep**: Read everything, search raw sources, peek sibling wikis.

Always cite sources. Note confidence levels. Identify gaps. Never use training data — only wiki content.

For any boot, resume, or "where you left off" briefing, start with the active
wiki identity: `<wiki-name> booted from <wiki-root-path>`. Prefer the title from
`config.md`; for local `.wiki/` projects, fall back to the parent directory name
(for example `bitcoin-wiki` for `.../claude-sandbox/bitcoin-wiki/.wiki`); for
`HUB/topics/<slug>/`, fall back to the slug. Include this line even when there
is nothing in flight to resume.

### Research

Automated pipeline: search → ingest → compile. Launch parallel agents. Auto-detects input type.

**Input detection**: If the input is a question (starts with what/why/how, contains "?", phrased as a goal), enters Question Mode. Otherwise, Topic Mode.

**Topic Mode** — explore a subject area:
- **Standard (5 agents)**: Academic, Technical, Applied, News/Trends, Contrarian
- **Deep (8 agents)**: Adds Historical, Adjacent fields, Data/Stats
- **Retardmax (10 agents)**: Adds 2 Rabbit Hole agents. Skip planning, ingest aggressively.

**Question Mode** — answer a specific question with a deliverable:
1. Decompose into 3-5 sub-questions (what/why/how/who/data)
2. One agent per sub-question (focused, not generic angles)
3. Compile into wiki articles + a synthesis "playbook" topic article
4. Auto-generate a playbook output artifact (the actionable deliverable)
5. Suggest 2-3 testable theses from findings → feed into `--mode thesis`

**Modifiers**: `--new-topic` (create wiki + research in one shot), `--plan` (decompose into 3-5 parallel paths, confirm, dispatch all at once — parallel ingest, sequential compile), `--mode thesis "<claim>"` (thesis-driven research with for/against framing and verdict), `--min-time <duration>` (sustained multi-round research), `--sources <N>` (per round).

Each agent receives a standardized prompt template: Objective, Context, Current wiki state, Constraints, Return format, Quality scoring guide (5=peer-reviewed → 1=spam). Deduplicate across agents.

**Phase 2b: Credibility Review** — after agents return, before ingestion: score each source on peer-review status (+2), recency (+1), author authority (+1), vendor primary source (-1), potential bias (-1), corroboration (+1 per agent, max +2). Tiers: High (4-6) → Medium (2-3) → Low (0-1) → Reject (<0). Bias signals do not stack.

**Session Files** (`--min-time` research, thesis, audit, refresh, output): Two ephemeral files plus two durable files in wiki root.

*Ephemeral* — `.research-session.json` (and `.thesis-session.json` for `--mode thesis`) — track round number, sources, articles, gaps, progress score for live crash recovery. Created at session start, updated each round, deleted on normal completion, persisted with `status: "in_progress"` if interrupted.

*Durable* — `.session-events.jsonl` is an append-only event log (one JSON object per line: ISO timestamp, session_id, command, phase, event name, metadata). `.session-checkpoint.json` is the latest-summary file (status, current_round, summary stats, artifacts with sha256), rewritten atomically at each milestone. **Both files persist after normal completion** — that is the point. Never delete them.

Lifecycle: at start, create the ephemeral file, append a `*_started` event, write the initial checkpoint. At each round, update all three. On normal completion, append the completion event, refresh the checkpoint, delete *only* the ephemeral file. On interruption, leave everything in place.

**Resume protocol**: On new invocation, check for an active ephemeral file first. If absent, read `.session-checkpoint.json` and the tail of `.session-events.jsonl` for the last durable context. Always ask "continue or start fresh?" before assuming. Files older than 7 days warrant a stale-session warning.

**Progress Scoring**: Each round scored 0-100: sources×3 + articles×5 + cross-refs×2 + credibility×4. Trajectory triggers: 3 consecutive declines totaling 30+ points → warn. Score ≥80 + no gaps → early completion. Score <40 → change strategy.

**Plan Reflection**: Between rounds, reflect holistically on ALL prior findings (not just latest gaps). Priority: draw cross-topic connections → update cross-references → re-evaluate gaps → score remaining gaps (Impact × Feasibility × Specificity) → adjust direction only if clearly needed.

Compile all ingested sources. Report gaps and suggest follow-ups.

### Thesis (mode of Research)

Thesis-driven research. Activated via `--mode thesis "<claim>"` on the research command. Previously a separate `/wiki:thesis` command (merged to eliminate duplicated infrastructure).

1. Decompose thesis into: core claim, key variables, testable prediction, falsification criteria, scope boundary
2. Agents split by purpose: Supporting, Opposing, Mechanistic, Meta/Review, Adjacent (+ Historical, Quantitative, Confounders in deep mode)
3. The thesis is the bloat filter — sources irrelevant to the claim's variables get skipped
4. Compile evidence into wiki articles + a thesis file with evidence tables (for/against/nuance)
5. Verdict: Supported / Partially Supported / Contradicted / Insufficient Evidence / Mixed (with confidence level)
6. Anti-confirmation-bias: in `--min-time` mode, Round 2 focuses harder on the WEAKER side of Round 1's evidence
7. Suggest follow-up theses derived from findings

### Retract

Remove a regretted source and clean up its downstream effects. Requires `--reason`.

1. **Identify**: Find the source file (by path or filename search)
2. **Map blast radius**: Grep all wiki articles for references — classify as frontmatter, body-inline, or see-also
3. **Clean up articles**: Remove metadata references, flag inline claims with `<!--RETRACTED-SOURCE-->` markers
4. **Delete raw source**: Remove file, update all indexes
5. **Log**: Permanent retraction record with reason
6. **Recompile** (optional `--recompile`): Rewrite flagged sections from remaining sources, remove markers
7. **Report**: Summary of changes + remaining review items

`--dry-run` shows blast radius without making changes. If a source is the only source for an article, warn prominently.

### Refresh

Freshness check for wiki articles. Re-fetches source URLs, detects changes (cosmetic, additive, contradictory), and presents a human-gated assessment. Three tiers: source check → change assessment → action decision (skip/update/flag/retract). `--due` flag shows all articles past their volatility threshold. Never auto-recompiles — human confirms every change.

### Lint

Health checks with auto-fix capability. Lint **is** the migration path — there is no separate `/wiki:migrate` command. A file in the wrong place from an old wiki layout and a file in the wrong place from user error are treated as the same defect. Two layers:

- **Mechanical (C11/C12/C13)** — `raw/` + `wiki/` file placement and frontmatter schema. Fully auto-fixable.
- **Project-level (C8/C9)** — `output/projects/` structure, `WHY.md` presence, staleness detection, and grouping candidates. Migration of legacy `_project.md` manifests (from pre-v0.2 wikis) is auto-fixed (C8c); everything else is surfaced as suggestions or ready-to-paste commands.

**Checks**: structure integrity, frontmatter validity (plus legacy key/value aliases C13), canonical placement of raw/wiki files (C11), unknown-file quarantine for raw/wiki/root (C12), index consistency, link integrity, source provenance (dangling refs, unresolved retraction markers), tag hygiene, coverage, project `WHY.md` presence (C8a), project staleness via source chain (C8b), legacy `_project.md` migration to `WHY.md` (C8c), project candidates (C9), deep fact-checking (optional).

**Auto-fix** (`--fix`): rewrite legacy frontmatter keys/values to canonical (C13), move misplaced raw/wiki files to their canonical directory (C11), quarantine unknown files to `inbox/.unknown/` (C12), migrate legacy `_project.md` to `WHY.md` (C8c), missing indexes, orphan files, dead index entries, statistics mismatch, missing bidirectional links, empty frontmatter fields, dangling source references, regenerate projects-aware `output/_index.md`. Never auto-delete unknown directories. Never auto-create `WHY.md` with placeholder goals (C8a is warn-only — manufactured rationale is worse than missing). Never auto-move files into projects (C9 is human-authored via `/wiki:project`). On slug collisions during a placement move, skip and warn.

**Schema evolution**: when canonical paths or frontmatter fields for `raw/` or `wiki/` change, update the rules in `skills/wiki-manager/references/linting.md` (C11 placement map, C12 allowlist, C13 alias table). When the project model changes, update C8/C9 and `projects.md`. Never write version-specific migration code. Lint rules are the schema.

### Search

Find content by keyword, tag, or category. Scan indexes first (fast), then full-text search.

### Output

Generate artifacts from wiki content: summary, report, study-guide, slides, timeline, glossary, comparison.

**Retardmax mode**: Read ALL articles, generate immediately without planning structure. Ship rough, iterate later.

Save to `output/`. Update indexes.

### Assess

Compare a local repo against wiki research + market.

1. **Repo scan** (3 parallel agents): structure, features, docs
2. **Wiki scan**: knowledge map from indexes and articles
3. **Gap analysis**: alignment, research gaps (repo does it, wiki doesn't), opportunities (wiki knows it, repo doesn't), neither covers
4. **Market scan** (3-5 parallel agents): competitors, best practices, emerging trends

Output: comparison report with feature matrix, competitive landscape, and recommended actions (specific research and build suggestions).

### Audit

Truth-seeking umbrella inspection across the whole artifact graph. If librarian
keeps the `wiki/` layer in check, audit answers the broader question: can the
user trust the current knowledge and outputs right now?

**Default behavior**:
- Reuse or rerun the librarian pass for wiki articles
- Audit output artifacts across `output/`, `wiki/`, and `raw/` dependency chains
- Follow the evidence outward when local material is weak, stale, contradictory,
  or missing
- Run targeted support and attack research before settling on a verdict
- Write `.audit/REPORT.md` and `.audit/scan-results.json`

**Verdicts**:
- `supported`
- `weakened`
- `contradicted`
- `unresolved`

**Provenance classification**: Audit reads `.session-events.jsonl` and `.session-checkpoint.json` to grade the audited run. Both present + recent + matching session_id → `replayable`. Either missing or stale → `partial`. Agents that maintain only ephemeral session files break replayability — durable files are required.

Flags: `--artifact <path>`, `--project <slug>`, `--wiki-only`, `--outputs-only`,
`--quick`, `--fresh`.

### Librarian

Content-level wiki maintenance: staleness detection, quality scoring, factual verification, semantic coherence, deduplication. Produces scored reports — never modifies content without confirmation.

**Subcommands**:
- **scan**: Score all wiki articles for staleness and quality. Two-tier: quick metadata scan first, deep content read only for articles below threshold or with `volatility: hot`. Checkpoints after each article for crash recovery. Results to `.librarian/scan-results.json` and `.librarian/REPORT.md`.
- **report**: Display the latest scan report.
- **fix <id>**: Apply a proposed fix from the report (Phase 3 — not yet implemented).

**Staleness scoring** (0-100): four dimensions at 25 points each — source freshness, verification recency, compilation recency, source chain integrity. Decay curves scaled by article `volatility` tier (hot/warm/cold).

**Quality scoring** (0-100): four dimensions at 25 points each — source diversity, content depth, cross-reference density, summary quality. Articles scoring below 40 on either dimension are flagged.

Flags: `--article <path>` (single article), `--resume` (from checkpoint), `--passes <list>` (staleness, quality — future: verification, coherence, dedup).

### Plan

Generate implementation plans grounded in wiki research. Six-stage pipeline: context assembly → interview → gap research → synthesis → plan generation → save.

1. **Context assembly**: Read wiki deeply, identify relevant articles, supporting context, and knowledge gaps
2. **Interview** (skip with `--no-interview` or `--quick`): 3-7 clarifying questions informed by wiki content
3. **Gap research** (skip with `--no-research` or `--quick`): Targeted web searches to fill knowledge gaps
4. **Synthesis**: Merge wiki evidence + interview answers + gap research
5. **Plan generation**: Output in requested format
6. **Save**: Write to `output/plan-{slug}-{date}.md`, update indexes and log

**Formats**: `--format roadmap` (default — phased plan with architecture decisions), `--format rfc` (Google/Uber style), `--format adr` (Architecture Decision Records), `--format spec` (technical specification).

Use `--with <wiki>` to load supplementary wikis as craft/skill context alongside the primary domain wiki.

### Project

Manage projects within a topic wiki. Projects are folders under `output/projects/` that group related outputs with a goal captured in `WHY.md`.

- **new <slug> "goal"**: Create project directory with `WHY.md`
- **list**: Show all projects with status and output counts
- **show <slug>**: Display project details, WHY.md, and outputs
- **archive <slug>**: Mark project as archived

Projects are a lightweight overlay — they don't move or copy wiki content.

### Lessons Learned (ll)

Extract lessons from the current session — error→fix patterns, user corrections, discoveries, gotchas — and save structured knowledge to the wiki pipeline.

**7-stage pipeline**: scan conversation → extract patterns → target topic wiki → write raw note → update relevant articles → suggest rule additions → log.

Flags: `--dry-run` (preview without writing), `--rules` (also propose CLAUDE.md/AGENTS.md rule additions).

## Structural Guardian

Auto-run lightweight checks after write operations:

1. Hub should only have wikis.json, _index.md, log.md, topics/. Delete anything else.
2. Index freshness: file counts match index rows. Auto-fix mismatches.
3. Orphan detection: files not in any index → add them.
4. Missing directories → create with empty _index.md.
5. wikis.json sync: all topic dirs registered, no ghost entries.

Silent when clean. Auto-fix trivial issues. Warn on structural problems. Never block the user.

## File Naming

- Raw sources: `YYYY-MM-DD-descriptive-slug.md`
- Wiki articles: `descriptive-slug.md` (no date — living documents)
- Output artifacts: `{type}-{topic-slug}-{YYYY-MM-DD}.md`
- All lowercase, hyphens, no special chars, max 60 chars

## Tag Convention

Lowercase, hyphenated. Specific over general (`transformer-architecture` not `ai`). Normalize — no near-duplicates.

## Obsidian Compatibility

Each topic wiki can be opened as an Obsidian vault. The `.obsidian/` config is created on init with sane defaults. Dual-links power the graph view. Aliases enable search by alternate names. Tags are natively read. The hub has NO `.obsidian/` to avoid nested vault confusion.

## Platform-Specific Notes

This AGENTS.md works with any LLM agent that can read/write files and search the web. Adapt tool names as needed:

| Capability | Claude Code | OpenAI Codex | Generic |
|-----------|------------|-------------|---------|
| Read file | `Read` | `file_read` | read the file |
| Write file | `Write` | `file_write` | write the file |
| Edit file | `Edit` | `file_edit` | edit the file |
| Search files | `Grep` | `shell(grep)` | search file contents |
| Find files | `Glob` | `shell(find)` | find files by pattern |
| Web search | `WebSearch` | `browser` | search the web |
| Fetch URL | `WebFetch` | `browser` | fetch URL content |
| Run command | `Bash` | `shell` | run shell command |
| Subagents | `Agent` | parallel tasks | spawn parallel work |
