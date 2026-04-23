---
description: "Ask questions against the compiled wiki. Supports quick/standard/deep depth levels, --list for browsing, and --resume to reload context after a session break. Answers from wiki content only, with citations."
argument-hint: "<question> [--quick] [--deep] [--raw] [--list] [--resume] [--tag <tag>] [--category concepts|topics|references] [--with <wiki>...] [--wiki <name>] [--local]"
allowed-tools: Read, Glob, Grep, Bash(ls:*), Edit
---

## Your task

**Resolve the wiki.** Do NOT search the filesystem or read reference files — follow these steps:
1. Read `$HOME/wiki/_index.md`. If it exists → HUB = `$HOME/wiki`. Skip to step 3.
2. If not → read `$HOME/.config/llm-wiki/config.json`. Use `resolved_path` as HUB. If only `hub_path` exists, expand leading `~` only (not tildes in `com~apple~CloudDocs`), set HUB, write `resolved_path` back. If no config → HUB = `$HOME/wiki`.
3. **Wiki location** (first match): `--local` → `.wiki/` in CWD; `--wiki <name>` → `HUB/wikis.json` lookup; CWD has `.wiki/` → use it; else → HUB.
4. Read `<wiki>/_index.md` to verify. If missing → stop with "No wiki found (or no articles compiled). Run `/wiki init` and `/wiki:compile` first."

Answer the question in $ARGUMENTS using ONLY the knowledge in the wiki. Follow the Q&A protocol below.

### Parse $ARGUMENTS

- **question**: Everything that is not a flag
- **--quick**: Fast answer from indexes only (no full article reads)
- **--deep**: Thorough answer — read all related articles, follow all links, search raw, peek sibling wikis
- **--raw**: Also search raw sources (implied by --deep)
- **--list**: Return a ranked list of matching articles instead of a synthesized answer. Useful for browsing what the wiki has on a topic before diving in.
- **--resume**: Load recent activity context and show a "where you left off" briefing. If a question is also provided, answer it after the briefing using standard depth.
- **--tag <tag>**: Filter to articles with this tag in frontmatter
- **--category <cat>**: Search only in concepts, topics, or references
- **--with <wiki>**: Load a supplementary wiki as additional context when answering. The primary wiki provides the subject; `--with` wikis provide craft/skill knowledge. Multiple `--with` flags allowed.
- No depth flag = **standard** (default)

### Index Freshness Check

Before using any `_index.md`, verify it's current: count `.md` files in the directory (excluding `_index.md`) and compare against rows in the index table. If counts differ, rebuild the index inline from file frontmatter before proceeding. See `references/indexing.md` Derived Index Protocol.

### Query Depth Levels

#### Quick (`--quick`)

Fastest. For simple factual lookups.

1. Read master `_index.md` and relevant category `_index.md` files
2. Answer using ONLY the summaries and tags in the index tables
3. Cite which index entries were used
4. If the indexes don't contain enough to answer, say so and suggest re-running without `--quick`

#### Standard (default)

Balanced. For most questions.

1. **Navigate via indexes** (3-hop strategy):
   - Read master `_index.md` → identify which categories are relevant
   - Read those category `_index.md` files → match summaries and tags to the question
   - Identify 3-8 most relevant articles

2. **Read relevant articles**: Read the identified articles in full. Follow "See Also" links if they appear directly relevant.

3. **Full-text search**: Use Grep to search `wiki/` for key terms from the question that the index might not have surfaced.

4. **Synthesize answer**:
   - Directly answer the question
   - Cite specific wiki articles with dual-links
   - Note connections between concepts from different articles
   - Note confidence levels of cited articles
   - Identify gaps

#### Deep (`--deep`)

Most thorough. For complex questions requiring cross-referencing.

1. **Full index scan**: Read ALL `_index.md` files across all categories

2. **Read all relevant articles**: Read every article that could be relevant (err on the side of reading more). Follow ALL "See Also" links, even tangentially related ones.

3. **Full-text search**: Grep `wiki/` AND `raw/` for key terms, synonyms, and related concepts

4. **Read raw sources**: Read any raw sources that seem relevant but may not be fully compiled into articles yet

5. **Sibling wiki peek**:
   - Read `HUB/wikis.json`
   - For each sibling wiki, read its `_index.md`
   - If overlap found, note it with specific article references

6. **Synthesize comprehensive answer**:
   - Thorough answer with full citations
   - Cross-reference information from multiple articles
   - Note confidence levels and any disagreements between sources
   - Note where raw sources contain detail not yet in compiled articles
   - Identify all gaps and suggest specific sources to ingest

### List Mode (`--list`)

When `--list` is set, return a ranked list of matching articles instead of a synthesized answer. This replaces the old `/wiki:search` command.

1. **Index scan**: Read relevant `_index.md` files. Check summaries and tags for matches.
   - If `--category` specified, only read that category's index
   - Otherwise read all category indexes under `wiki/`

2. **Full-text search**: Use Grep to search `wiki/` for the query terms.
   - If `--raw`, also search `raw/`

3. **Tag filter**: If `--tag` specified, use Grep to find files with matching tags in YAML frontmatter: `tags:.*<tag>`.

4. **Rank results**: Present ordered by relevance:
   - Title match > summary match > body match
   - Multiple term matches > single term match
   - More recent > older

**Output format for --list:**

```
## Search Results for "<query>"

Found N results:

### Wiki Articles
1. **[Title](path)** — summary — tags: tag1, tag2
2. **[Title](path)** — summary — tags: tag1

### Raw Sources (if --raw)
1. **[Title](path)** — summary — type: articles
```

If no results found, suggest alternative search terms or `/wiki:ingest` to add sources.

Skip the synthesized answer, sources used, and knowledge gaps sections. Just return the list.

### Resume Mode (`--resume`)

Context reload for new sessions. Reads persistent state and outputs a briefing so you can pick up where you left off.

1. **Check for interrupted sessions**: Try to read `.research-session.json` and `.thesis-session.json` in the wiki root. If either exists with `status: "in_progress"`, report: topic/thesis, current round, sources so far, last round's gaps or verdict direction.

2. **Recent activity**: Read `log.md`. Extract the last 10 entries (grep for `^## \[`). Present them as a compact timeline.

3. **Wiki stats**: Read `_index.md` — pull total source count, article count, and output count from the stats section.

4. **Most recent work**: Read the master `_index.md` table. Identify the 3 most recently updated articles by their `Updated` column. Show their titles, paths, and summaries from the index (do NOT read full articles — keep it fast).

5. **Suggested next steps**: Based on what you found:
   - If interrupted session exists → suggest resuming it (e.g., "Run `/wiki:research --min-time ...` to continue")
   - If recent research logged gaps → suggest addressing them
   - If recent ingests have no corresponding compile → suggest `/wiki:compile`
   - If nothing recent → suggest `/wiki:research` or `/wiki:ingest` to add material

**Output format:**

```
## Resume: <wiki-title>

**Interrupted session?** Yes — research on "<topic>", round N, M sources so far. Last gaps: ...
(or: No interrupted sessions.)

**Recent activity** (last 10 ops):
- YYYY-MM-DD: operation | description
- ...

**Wiki stats**: N sources, M articles, K outputs

**Last updated articles**:
- [Article](path) — summary
- [Article](path) — summary
- [Article](path) — summary

**Suggested next steps**:
- ...
```

**If a question is also provided**: After the briefing, answer the question using standard depth. Include the usual Sources used / Knowledge gaps sections for the answer portion only.

**If no question**: Skip the Sources used / Knowledge gaps sections entirely — just the briefing.

**Log**: Append `## [YYYY-MM-DD] query | --resume briefing`

### Output Format (all depths, not --list)

[Answer in clear prose with markdown formatting]

---
**Sources used:**
- [Article 1](path) (confidence: high) — what was drawn from it
- [Article 2](path) (confidence: medium) — what was drawn from it

**Related in other wikis:** (if any, or if --deep)
- [wiki-name]: [Article Title] — appears relevant

**Knowledge gaps:** (if any)
- What the wiki doesn't cover that would help answer this better
- Suggested sources to ingest

### Log

Append to `log.md`: `## [YYYY-MM-DD] query | "question" → answered from N articles (depth)`

IMPORTANT: Do NOT use information from your training data. Answer ONLY from wiki content. If the wiki doesn't have the answer, say so honestly.
