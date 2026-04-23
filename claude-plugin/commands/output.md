---
description: "Generate output artifacts from wiki content — summaries, reports, study guides, slide outlines, timelines, glossaries, comparisons. Outputs are filed back into the wiki."
argument-hint: "<type> [--topic <topic>] [--sources <paths>] [--with <wiki>...] [--wiki <name>] [--local]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(date:*), Bash(python3:*)
---

## Your task

**Resolve the wiki.** Do NOT search the filesystem or read reference files — follow these steps:
1. Read `$HOME/.config/llm-wiki/config.json`. If it has `resolved_path` → HUB = that value, skip to step 3. If only `hub_path`, expand leading `~` only (not tildes in `com~apple~CloudDocs`), set HUB, write `resolved_path` back, skip to step 3.
2. If no config → read `$HOME/wiki/_index.md`. If it exists → HUB = `$HOME/wiki`. If nothing found, ask the user where to create the wiki.
3. **Wiki location** (first match): `--local` → `.wiki/` in CWD; `--wiki <name>` → `HUB/wikis.json` lookup; CWD has `.wiki/` → use it; else → HUB.
4. Read `<wiki>/_index.md` to verify. If missing → stop with "No wiki found (or no articles). Run `/wiki init` and `/wiki:compile` first."

Generate an output artifact from wiki content based on $ARGUMENTS.

### Parse $ARGUMENTS

- **type** (required): One of: `summary`, `report`, `study-guide`, `slides`, `timeline`, `glossary`, `comparison`
- **--topic <topic>**: Focus on a specific topic or concept (matches against tags and titles)
- **--sources <paths>**: Comma-separated list of specific wiki article paths to use
- **--with <wiki>**: Load a supplementary wiki as additional context. The primary wiki (`--wiki`) provides the **subject** (what to write about); `--with` wikis provide **craft/skill** knowledge (how to write it). Multiple `--with` flags allowed. Example: `--wiki quantum-computing --with article-writing` uses quantum-computing for domain content and article-writing for structure, hooks, and writing techniques.
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

2. **Load supplementary wikis** (if `--with` specified):
   - For each `--with <name>`, look up in `HUB/wikis.json`
   - Read the supplementary wiki's `_index.md` and relevant articles
   - These provide **craft/skill context** — techniques, frameworks, writing patterns, best practices
   - The primary wiki provides the **subject matter** — facts, research, domain knowledge
   - When generating, apply the supplementary wiki's techniques to the primary wiki's content
   - Example: `--with article-writing` means use that wiki's knowledge about hooks, structure, E-E-A-T, viral patterns, debunking techniques, etc. when crafting the output

3. **Generate**: Create the artifact in the format specified for the output type. Draw domain content from the primary wiki and craft/technique guidance from `--with` wikis.

3. **Save**: Write to `output/{type}-{topic-slug}-{YYYY-MM-DD}.md`. Follow core principle #9 (chunked writes): Write frontmatter + first section, then Edit to append remaining sections. With frontmatter:
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
