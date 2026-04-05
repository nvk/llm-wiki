# llm-wiki

A Claude Code plugin for building LLM-compiled knowledge bases. Ingest sources, compile interconnected markdown articles, query, lint, research, and generate outputs — all from Claude Code. Optionally view in Obsidian.

Inspired by [Karpathy's LLM wiki concept](https://x.com/karpathy/status/2039805659525644595) and his [idea file](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f).

## Install

```
/install-plugin github:nvk/llm-wiki
```

## Quick Start

```
/wiki init                              # Create your knowledge base at ~/wiki/
/wiki:ingest https://example.com        # Ingest a web article
/wiki:ingest --inbox                    # Process files dropped in ~/wiki/inbox/
/wiki:compile                           # Compile sources into wiki articles
/wiki:query "How does X work?"          # Ask questions against the wiki
/wiki:research "topic to explore"       # Automated multi-agent research
```

## Commands

| Command | Description |
|---------|-------------|
| `/wiki` | Show wiki status, stats, and list of wikis |
| `/wiki init` | Create a global wiki at `~/wiki/` |
| `/wiki init --local` | Create a project-local wiki at `.wiki/` |
| `/wiki init ml --topic` | Create a sub-wiki at `~/wiki/topics/ml/` |
| `/wiki:ingest <source>` | Ingest a URL, file path, or quoted text |
| `/wiki:ingest --inbox` | Process all files in `~/wiki/inbox/` |
| `/wiki:compile` | Compile new sources into wiki articles |
| `/wiki:compile --full` | Recompile everything from scratch |
| `/wiki:query <question>` | Q&A against the wiki (standard depth) |
| `/wiki:query <question> --quick` | Fast answer from indexes only |
| `/wiki:query <question> --deep` | Thorough answer — reads everything, checks raw + sibling wikis |
| `/wiki:research <topic>` | Multi-agent deep research: search web, ingest, compile |
| `/wiki:research <topic> --sources 10` | Research with target source count |
| `/wiki:search <terms>` | Find content by keyword or tag |
| `/wiki:lint` | Run health checks on the wiki |
| `/wiki:lint --fix` | Auto-fix structural issues |
| `/wiki:lint --deep` | Web-verify facts and suggest improvements |
| `/wiki:output summary` | Generate a summary of a topic |
| `/wiki:output report --topic X` | Generate a detailed report |
| `/wiki:output slides --topic X` | Generate a slide deck |
| `/wiki:output study-guide` | Generate a study guide |
| `/wiki:output glossary` | Generate a glossary of terms |

All commands accept `--wiki <name>` to target a specific wiki and `--local` to target the project wiki.

## How It Works

### Architecture

```
~/wiki/
├── .obsidian/      # Obsidian vault config (auto-created)
├── inbox/          # Drop zone — dump files here, run /wiki:ingest --inbox
├── raw/            # Immutable source material (articles, papers, repos, notes, data)
├── wiki/           # Compiled articles (concepts, topics, references)
├── output/         # Generated artifacts (summaries, reports, slides, etc.)
├── topics/         # Sub-wikis by topic
├── log.md          # Append-only activity log
├── config.md       # Wiki title, scope, conventions
└── wikis.json      # Tracks all wikis (global, topic, local)
```

### The Flow

1. **Ingest** sources into `raw/` — URLs, files, text, tweets (via Grok MCP), or bulk via inbox
2. **Compile** raw sources into synthesized wiki articles with cross-references and confidence scores
3. **Query** the wiki — quick (indexes), standard (articles), or deep (everything)
4. **Research** topics automatically — parallel web search, ingest, and compile in one command
5. **Lint** for consistency — broken links, missing indexes, orphan articles
6. **Output** artifacts — summaries, reports, slides — filed back into the wiki

### Key Design

- **Global by default** at `~/wiki/`, with `--local` for project-specific wikis
- **`_index.md` navigation** — every directory has an index. Claude reads indexes first, never scans blindly
- **Articles are synthesized**, not copied — they explain, contextualize, cross-reference
- **Raw is immutable** — once ingested, sources are never modified
- **Multi-wiki aware** — queries check sibling wiki indexes for overlap
- **Dual-linking** — both `[[wikilinks]]` (Obsidian) and standard markdown links (Claude) on every cross-reference
- **Confidence scoring** — articles rated high/medium/low based on source quality
- **Activity log** — `log.md` tracks every operation, append-only, grep-friendly
- **Zero dependencies** — runs entirely on Claude Code built-in tools

## Obsidian Integration

Open `~/wiki/` as an Obsidian vault. It works out of the box:

- `.obsidian/` config created on init with sane defaults
- `[[wikilinks]]` on all cross-references power the graph view
- `aliases` in frontmatter enable Obsidian search by alternate names
- `tags` in frontmatter are natively read by Obsidian
- `inbox/` works as a natural drop zone in both Obsidian and the CLI

Claude Code is the compiler. Obsidian is an optional viewer. You never need Obsidian — but if you use it, everything connects.

## Ambient Intelligence

The wiki-manager skill auto-activates when you ask knowledge questions in any project. If the wiki has relevant content, it surfaces it with citations. No `/wiki:query` needed for casual questions.

## Query Depths

| Depth | Flag | What it does |
|-------|------|-------------|
| Quick | `--quick` | Reads indexes only. Fastest. For simple lookups. |
| Standard | *(default)* | Reads relevant articles + full-text search. For most questions. |
| Deep | `--deep` | Reads everything, searches raw sources, peeks sibling wikis. For complex research questions. |

## Credits

- [Andrej Karpathy](https://x.com/karpathy) — the LLM wiki concept and idea file
- [tobi/qmd](https://github.com/tobi/qmd) — recommended local search engine for scaling beyond ~100 articles
- [rvk7895/llm-knowledge-bases](https://github.com/rvk7895/llm-knowledge-bases) — prior art in Claude Code wiki plugins

## License

MIT
