---
description: "Ask questions against the compiled wiki. Supports three depth levels: quick (indexes only), standard (full articles), deep (everything + raw + sibling wikis). Answers from wiki content only, with citations."
argument-hint: "<question> [--quick] [--deep] [--raw] [--wiki <name>] [--local]"
allowed-tools: Read, Glob, Grep, Bash(ls:*), Edit
---

## Your task

First, resolve **HUB** by following the protocol in `references/hub-resolution.md` (read config, expand leading `~` only, quote paths with spaces). Then check if a wiki exists by trying to read `HUB/_index.md` (global hub) and `.wiki/_index.md` (local).

Answer the question in $ARGUMENTS using ONLY the knowledge in the wiki. Follow the Q&A protocol below.

### Resolve wiki location

1. `--local` → `.wiki/`
2. `--wiki <name>` → look up in `HUB/wikis.json`
3. Current directory has `.wiki/` → use it
4. Otherwise → HUB

If wiki does not exist or has no compiled articles, stop: "No wiki found (or no articles compiled). Run `/wiki init` and `/wiki:compile` first."

### Parse $ARGUMENTS

- **question**: Everything that is not a flag
- **--quick**: Fast answer from indexes only (no full article reads)
- **--deep**: Thorough answer — read all related articles, follow all links, search raw, peek sibling wikis
- **--raw**: Also search raw sources (implied by --deep)
- No depth flag = **standard** (default)

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

### Output Format (all depths)

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
