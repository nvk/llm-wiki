# Compilation Protocol

## Overview

Compilation transforms raw sources into wiki articles. This is the core "LLM compiler" operation — read sources and produce synthesized, cross-referenced knowledge articles.

## Incremental vs Full

- **Incremental** (default): Only process sources ingested since the last compilation date (from master `_index.md`). Compare source `ingested` dates against `Last compiled` in master index.
- **Full** (`--full`): Re-read all sources, rewrite all articles. Expensive but ensures consistency.

## The Compilation Loop

### Step 1: Survey

1. Read `raw/_index.md` to see all sources
2. Read `wiki/_index.md` to see existing articles
3. For incremental: identify sources with `ingested` date after last compile date
4. For full: use all sources
5. Read each uncompiled source in full

### Step 2: Extract

For each source, identify:
- **Key concepts**: nouns, technical terms, named entities
- **Key facts**: claims, data points, measurements, relationships
- **Key relationships**: X relates to Y, X is a type of Y, X was created by Y

### Step 3: Map to Existing Wiki

Read `wiki/_index.md` and category indexes. For each key concept:
- Already has an article? → plan to UPDATE it with new information
- Major concept worthy of its own article? → plan to CREATE one
- Minor mention? → will be referenced within another article

### Step 4: Classify New Articles

- **concept**: A specific, bounded idea explainable in 1-3 pages. Examples: "Transformer Architecture", "Gradient Descent", "Docker Container"
- **topic**: A broader theme tying concepts together. Examples: "Deep Learning", "DevOps", "Functional Programming"
- **reference**: A curated list of resources, tools, or links. Examples: "Python ML Libraries", "Transformer Paper Timeline"

### Step 5: Write/Update Articles

**For new outputs with binary artifacts:** If a new output will produce binary siblings (images, diagrams, CSVs, rendered screenshots, code files), create it inside `output/projects/<slug>/` from the start rather than scattering into `output/` root. The reason is colocation — relative asset paths only work when the markdown and its assets live in the same folder. See `references/projects.md` for the full rationale. If the user passed `--project <slug>` explicitly, write into that project folder. Otherwise prompt for a slug and goal and invoke `/wiki:project new` before writing the artifacts. Loose markdown outputs (no binary siblings) can still land flat in `output/` for backward compatibility.

**For new articles:**

1. Write the abstract paragraph — what is this and why does it matter?
2. Write the body — explain using information from source(s). Synthesize, contextualize, explain. Do NOT copy-paste.
3. When referencing another wiki article inline, use dual-link format: `[[slug|Name]] ([Name](../category/slug.md))` — this serves both Obsidian and the agent.
4. Add "See Also" links to related wiki articles using dual-link format (check wiki index for related tags/concepts)
5. Add "Sources" section linking back to raw files
6. Generate frontmatter per `references/wiki-structure.md` — include `aliases` for alternate names
7. Add `aliases` in frontmatter for any common alternate names (e.g., `aliases: [GPT, Generative Pre-trained Transformer]`)
8. Set `confidence` in frontmatter based on source credibility AND corroboration:
   - `high`: multiple sources with credibility score 4+ agree, OR single peer-reviewed meta-analysis/systematic review
   - `medium`: single credible source (score 2-3), OR multiple sources partially agree, OR recent findings not yet replicated
   - `low`: single non-peer-reviewed source (score 0-1), OR sources disagree, OR anecdotal only

   When Phase 2b credibility scores are available, use them directly. When compiling without a preceding research phase (e.g., manual ingest → compile), assess credibility inline.

**For updated articles:**

1. Read the existing article
2. Identify what the new source adds (new facts, perspectives, connections)
3. Integrate new information into appropriate sections using Edit (not full rewrite)
4. Add the new source to the Sources section
5. Update the `updated` date in frontmatter
6. Check if new "See Also" links are warranted

### Step 6: Bidirectional Linking

For every "See Also" link from article A → article B:
- Check if B has a "See Also" link back to A
- If not, add one with a brief relationship note
- Use dual-link format: `[[slug|Name]] ([Name](../category/slug.md)) — relationship note`

### Step 7: Update All Indexes

After all articles are written/updated:

1. Each category `_index.md` (concepts, topics, references) — add/update rows
2. `wiki/_index.md` — add/update rows
3. Master `_index.md` — update article count, set "Last compiled" to today, add to Recent Changes
4. If `output/projects/` exists, regenerate `output/_index.md` as a projects-aware listing: scan each `output/projects/*/WHY.md` for its first `#` heading (title) and first non-heading paragraph (goal, first ~120 chars), list them as a table, then list any remaining loose outputs in `output/` below. This is **best-effort** — if skipped or clobbered by a concurrent session, the next lint/compile will fix it. Member counts per project come from folder scans at render time; there is no cached Members list on disk anymore (the v0.2 simplification removed the `_project.md` manifest, so there's nothing to regenerate inside the project folders themselves — see `references/projects.md`).

## Quality Standards

- **Self-contained**: Articles are readable without consulting raw sources
- **Synthesized**: Draw from multiple sources when possible, not just one
- **Accurate**: Do not simplify to the point of being wrong
- **Clear**: Direct language. Knowledge base, not blog post.
- **Honest disagreement**: When sources disagree, note the disagreement rather than picking a side
- **Connected**: Every article should link to at least one other article via "See Also"
