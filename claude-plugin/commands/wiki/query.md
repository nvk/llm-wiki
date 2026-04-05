---
description: "Ask questions against the compiled wiki. Answers from wiki content only, with citations. Peeks at sibling wikis for overlap."
argument-hint: "<question> [--wiki <name>] [--local] [--raw]"
allowed-tools: Read, Glob, Grep, Bash(ls:*)
---

## Your task

First, check if a wiki exists by trying to read `~/wiki/_index.md` (global) and `.wiki/_index.md` (local).

Answer the question in $ARGUMENTS using ONLY the knowledge in the wiki. Follow the Q&A protocol below.

### Resolve wiki location

1. `--local` → `.wiki/`
2. `--wiki <name>` → look up in `~/wiki/wikis.json`
3. Current directory has `.wiki/` → use it
4. Otherwise → `~/wiki/`

If wiki does not exist or has no compiled articles, stop: "No wiki found (or no articles compiled). Run `/wiki init` and `/wiki:compile` first."

### Parse $ARGUMENTS

- **question**: Everything that is not a flag
- **--raw**: Also search raw sources, not just compiled articles

### Q&A Protocol

1. **Navigate via indexes** (3-hop strategy from `references/indexing.md`):
   - Read master `_index.md` → identify which categories are relevant
   - Read those category `_index.md` files → match summaries and tags to the question
   - Identify 3-8 most relevant articles

2. **Read relevant articles**: Read the identified articles in full. Follow "See Also" links if they appear relevant to the question.

3. **Full-text search**: Use Grep to search `wiki/` for key terms from the question that the index might not have surfaced.

4. **If --raw**: Also search `raw/` for additional detail not yet compiled into articles.

5. **Synthesize answer**:
   - Directly answer the question
   - Cite specific wiki articles: `[Article Title](path)`
   - Note connections between concepts from different articles
   - Identify gaps: if the wiki doesn't fully answer the question, say so and suggest what to ingest

6. **Peek at sibling wikis**:
   - If `~/wiki/wikis.json` exists, read it
   - For each sibling wiki, read ONLY its `_index.md`
   - If any summaries/tags overlap with the question, note: "Related content also exists in your [wiki-name] wiki: [Article Title]"
   - Do NOT read full articles from sibling wikis

7. **Format**:

   [Answer in clear prose with markdown formatting]

   ---
   **Sources used:**
   - [Article 1](path) — what was drawn from it
   - [Article 2](path) — what was drawn from it

   **Related in other wikis:** (if any)
   - [wiki-name]: [Article Title] — appears relevant

   **Knowledge gaps:** (if any)
   - What the wiki doesn't cover that would help answer this better
   - Suggested sources to ingest

IMPORTANT: Do NOT use information from your training data. Answer ONLY from wiki content. If the wiki doesn't have the answer, say so honestly.
