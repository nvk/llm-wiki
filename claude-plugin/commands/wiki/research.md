---
description: "Deep multi-agent research on a topic. Launches parallel agents to search the web across multiple angles, ingests sources, and compiles them into wiki articles."
argument-hint: "<topic> [--sources <N>] [--deep] [--wiki <name>] [--local]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*), WebFetch, WebSearch, Agent
---

## Your task

First, check if a wiki exists by trying to read `~/wiki/_index.md` (global) and `.wiki/_index.md` (local).

Conduct deep research on the topic in $ARGUMENTS. This is an automated pipeline: search → ingest → compile.

### Resolve wiki location

1. `--local` → `.wiki/`
2. `--wiki <name>` → look up in `~/wiki/wikis.json`
3. Current directory has `.wiki/` → use it
4. Otherwise → ask which topic wiki to target

If wiki does not exist, stop: "No wiki found. Run `/wiki init <topic>` first."

### Parse $ARGUMENTS

- **topic**: The research topic — everything that is not a flag
- **--sources <N>**: Target number of sources to find and ingest (default: 5, max: 20)
- **--deep**: Expanded research — launches more agents with broader search angles

### Research Protocol

#### Phase 1: Existing Knowledge Check

1. Read `wiki/_index.md` and `raw/_index.md` to understand what the wiki already knows
2. Use Grep to search for the topic and related terms across existing articles
3. Identify gaps — what specific aspects, subtopics, and questions are NOT covered?
4. Generate a list of 5-8 specific search angles based on the gaps

#### Phase 2: Web Research — Parallel Agent Swarm

Launch agents IN PARALLEL (single message, multiple Agent tool calls) to maximize coverage and speed.

**Standard mode (default):** 5 parallel agents

| Agent | Focus | Search Strategy |
|-------|-------|----------------|
| **Academic** | Peer-reviewed papers, meta-analyses, systematic reviews | Search Google Scholar, PubMed, arxiv. Prioritize recent (last 2 years). Look for landmark papers. |
| **Technical** | Technical deep-dives, specifications, documentation | Search for technical guides, whitepapers, official documentation, engineering blogs. |
| **Applied** | Case studies, real-world implementations, practical guides | Search for how-to guides, industry reports, practitioner perspectives, tutorials. |
| **News/Trends** | Recent developments, announcements, emerging research | Search for news from last 6 months, conference talks, announcements, trend analyses. |
| **Contrarian** | Criticisms, limitations, counterarguments, failed approaches | Search for critiques, rebuttals, known limitations, what doesn't work, common mistakes. |

**Deep mode (`--deep`):** 8 parallel agents — adds:

| Agent | Focus | Search Strategy |
|-------|-------|----------------|
| **Historical** | Origin, evolution, key milestones of the topic | Search for history, foundational papers, how the field evolved, key figures. |
| **Adjacent** | Related fields, interdisciplinary connections | Search for cross-domain applications, analogies from other fields, unexpected connections. |
| **Data/Stats** | Quantitative data, benchmarks, statistics, datasets | Search for surveys, benchmarks, statistical analyses, market data, datasets. |

**Each agent must:**
- Run 2-3 different WebSearch queries (vary terms, don't repeat)
- For each promising result, use WebFetch to extract the full content
- Evaluate quality: Is this authoritative? Peer-reviewed? Recent? Unique perspective?
- Return a ranked list: title, URL, extracted content, quality score (1-5), and why it's worth ingesting
- Target 3-5 high-quality sources per agent
- Skip: paywalled content, SEO spam, thin articles, duplicate information

**Deduplication:** After all agents return, deduplicate by URL and by content similarity. If two agents found the same source, keep it once. If two sources cover identical ground, keep the higher quality one.

#### Phase 3: Ingest

For each high-quality source (up to --sources count, ranked by quality score):

1. Write to `raw/{type}/YYYY-MM-DD-slug.md` with proper frontmatter (title, source URL, type, tags, summary)
2. Auto-detect type: academic → papers, news → articles, code → repos, guides → articles, data → data
3. Update `raw/{type}/_index.md` and `raw/_index.md`
4. Update master `_index.md` source count

#### Phase 4: Compile

1. Read all newly ingested sources
2. Follow the compilation protocol in `skills/wiki-manager/references/compilation.md`:
   - Extract key concepts, facts, relationships
   - Map to existing wiki articles
   - Create new articles or update existing ones
   - Use dual-link format for all cross-references
   - Set confidence levels based on source quality and corroboration:
     - Multiple agents found corroborating sources → high
     - Single source or recent/unverified → medium
     - Contrarian agent only, or anecdotal → low
   - Add bidirectional See Also links
3. Update all `_index.md` files
4. Update master `_index.md` with new stats

#### Phase 5: Report & Log

1. Append to topic wiki `log.md`: `## [YYYY-MM-DD] research | "topic" → N sources ingested, M articles compiled`
2. Append to hub `~/wiki/log.md`: same entry

3. Report:
   - **Topic researched**: the query
   - **Agents launched**: N (list which angles)
   - **Sources found**: N total across all agents
   - **Sources ingested**: M (list with URLs and quality scores)
   - **Sources skipped**: list with reason (low quality, duplicate, paywall, thin)
   - **Articles created**: list with paths and summaries
   - **Articles updated**: list with what was added
   - **Confidence map**: which claims are high/medium/low confidence and why
   - **New connections**: cross-references discovered between new and existing articles
   - **Remaining gaps**: what's still not covered
   - **Suggested follow-ups**: specific `/wiki:research "subtopic"` commands to go deeper
