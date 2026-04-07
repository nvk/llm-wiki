---
description: "Generate output artifacts from wiki content — summaries, reports, study guides, slide outlines, timelines, glossaries, comparisons. Outputs are filed back into the wiki."
argument-hint: "<type> [--topic <topic>] [--sources <paths>] [--wiki <name>] [--local]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(date:*), Bash(python3:*)
---

## Your task

First, resolve **HUB** by following the protocol in `references/hub-resolution.md` (read config, expand leading `~` only, quote paths with spaces). Then check if a wiki exists by trying to read `HUB/_index.md` (global hub) and `.wiki/_index.md` (local).

Generate an output artifact from wiki content based on $ARGUMENTS.

### Resolve wiki location

1. `--local` → `.wiki/`
2. `--wiki <name>` → look up in `HUB/wikis.json`
3. Current directory has `.wiki/` → use it
4. Otherwise → HUB

If wiki does not exist or has no articles, stop: "No wiki found (or no articles). Run `/wiki init` and `/wiki:compile` first."

### Parse $ARGUMENTS

- **type** (required): One of: `summary`, `report`, `study-guide`, `slides`, `timeline`, `glossary`, `comparison`
- **--topic <topic>**: Focus on a specific topic or concept (matches against tags and titles)
- **--sources <paths>**: Comma-separated list of specific wiki article paths to use
- **--retardmax**: Ship it NOW. Don't agonize over structure or completeness. Generate a rough-but-useful output fast, covering everything the wiki has. Better to have something imperfect now than something perfect never.

### Output Types

**summary**: A condensed overview of a topic or the entire wiki. 1-2 pages max. Key points, main takeaways.

**report**: A detailed analytical report with sections, evidence from articles, and conclusions. 3-5 pages.

**study-guide**: Key concepts with definitions, questions and answers, concept relationships. Designed for learning.

**slides**: A markdown slide deck using `---` as slide separators. Each slide has a title, 3-5 bullet points max. Suitable for Marp or similar renderers.

**timeline**: Chronological view of developments, events, or milestones in a topic area. Formatted as a dated list.

**glossary**: Definitions of all key terms found in the wiki (or a topic subset). Alphabetically sorted.

**comparison**: Structured comparison of 2+ concepts/technologies/approaches. Uses tables for feature-by-feature comparison.

### Retardmax Mode (`--retardmax`)

When `--retardmax` is set:
- Read ALL articles in the wiki, not just topic-matched ones. Don't filter, don't be selective.
- Generate the output immediately. Don't plan the structure first — just start writing.
- Include everything that might be relevant. Too much is better than too little.
- Don't worry about perfect formatting or transitions. Get the content down.
- If it's a report, make it comprehensive and raw. Polish comes later.
- If it's slides, more slides is fine. Trim later.
- File it and move on. The user can iterate with a non-retardmax pass.

### Process

1. **Gather sources**:
   - If `--retardmax`: read ALL wiki articles across all categories
   - If `--sources` provided: read those specific articles
   - If `--topic` provided: search wiki indexes for matching articles by tag/title, read them
   - If neither: read `wiki/_index.md` for an overview, read articles from each category

2. **Generate**: Create the artifact in the format specified for the output type. Draw only from wiki content.

3. **Save**: Write to `output/{type}-{topic-slug}-{YYYY-MM-DD}.md` with frontmatter:
   ```
   ---
   title: "Output Title"
   type: summary|report|study-guide|slides|timeline|glossary|comparison
   sources: [wiki articles used]
   generated: YYYY-MM-DD
   ---
   ```

4. **Update indexes**:
   - `output/_index.md` — add row
   - Master `_index.md` — increment output count, add to Recent Changes

5. **Log**: Append to `log.md`: `## [YYYY-MM-DD] output | {type} on {topic} → output/{filename}.md`

6. **Report**: What was generated, where saved, which source articles were used.
