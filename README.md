# llm-wiki

A Claude Code plugin for building LLM-compiled knowledge bases. Ingest sources, compile interconnected markdown articles, query, lint, research, and generate outputs — all from Claude Code. Optionally view in Obsidian.

Inspired by [Karpathy's LLM wiki concept](https://x.com/karpathy/status/2039805659525644595) and his [idea file](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f).

## Install

```
/install-plugin github:nvk/llm-wiki
```

> **New to a topic? Two commands.** Each topic gets its own wiki — isolated indexes, focused queries, no cross-topic noise:
> ```
> /wiki init quantum-computing
> /wiki:research "quantum error correction" --sources 10 --wiki quantum-computing
> ```
> The research command searches the web, ingests the best sources, and compiles them into interconnected articles. Drill into gaps with more `/wiki:research`, ask questions with `/wiki:query`, drop articles into the inbox anytime.

## Quick Start

```
/wiki init quantum-computing            # Create a topic wiki at ~/wiki/topics/quantum-computing/
/wiki:research "topic" --wiki qc        # Auto-research: search, ingest, compile
/wiki:query "How does X work?"          # Ask questions against the wiki
/wiki:query "compare X and Y" --deep    # Deep cross-referenced answer
/wiki:ingest https://example.com        # Manually ingest a specific source
/wiki:ingest --inbox                    # Process files dropped in inbox/
/wiki:compile                           # Compile any unprocessed sources
/wiki:output summary --topic X          # Generate a synthesis
/wiki:lint --fix                        # Clean up inconsistencies
```

## Commands

| Command | Description |
|---------|-------------|
| `/wiki` | Show wiki status, stats, and list all topic wikis |
| `/wiki init <name>` | Create a topic wiki at `~/wiki/topics/<name>/` |
| `/wiki init <name> --local` | Create a project-local wiki at `.wiki/` |
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
~/wiki/                                 # Hub — lightweight, no content
├── wikis.json                          # Registry of all topic wikis
├── _index.md                           # Lists topic wikis with stats
├── log.md                              # Global activity log
└── topics/                             # Each topic is an isolated wiki
    ├── dementia/                       # Example topic wiki
    │   ├── .obsidian/                  # Obsidian vault config
    │   ├── inbox/                      # Drop zone for this topic
    │   ├── raw/                        # Immutable sources
    │   ├── wiki/                       # Compiled articles
    │   │   ├── concepts/
    │   │   ├── topics/
    │   │   └── references/
    │   ├── output/                     # Generated artifacts
    │   ├── _index.md
    │   ├── config.md
    │   └── log.md
    ├── quantum-computing/              # Another topic wiki
    └── ...
```

Each topic wiki has its own indexes, sources, and articles — queries stay focused. The multi-wiki peek still finds overlap across topics when relevant.

### The Flow

1. **Ingest** sources into `raw/` — URLs, files, text, tweets (via Grok MCP), or bulk via inbox
2. **Compile** raw sources into synthesized wiki articles with cross-references and confidence scores
3. **Query** the wiki — quick (indexes), standard (articles), or deep (everything)
4. **Research** topics automatically — parallel web search, ingest, and compile in one command
5. **Lint** for consistency — broken links, missing indexes, orphan articles
6. **Output** artifacts — summaries, reports, slides — filed back into the wiki

### Key Design

- **One topic, one wiki** — each research area gets its own sub-wiki with isolated indexes. No cross-topic noise.
- **`_index.md` navigation** — every directory has an index. Claude reads indexes first, never scans blindly
- **Articles are synthesized**, not copied — they explain, contextualize, cross-reference
- **Raw is immutable** — once ingested, sources are never modified
- **Multi-wiki aware** — queries check sibling wiki indexes for overlap
- **Dual-linking** — every cross-reference uses both `[[wikilinks]]` and standard markdown links on the same line, so the wiki works with Obsidian, any markdown viewer, or no viewer at all. Not locked into any tool.
- **Confidence scoring** — articles rated high/medium/low based on source quality
- **Activity log** — `log.md` tracks every operation, append-only, grep-friendly
- **Zero dependencies** — runs entirely on Claude Code built-in tools

## Linking: Works Everywhere

Every cross-reference in the wiki uses dual-link format:

```markdown
[[self-attention|Self-Attention]] ([Self-Attention](../concepts/self-attention.md))
```

This is intentional. The wiki is **not locked into any tool**:

- **Obsidian** reads the `[[wikilink]]` — graph view, backlinks panel, and quick-open all work
- **Claude Code** follows the standard `(relative/path.md)` link — reads the right file every time
- **GitHub/any markdown viewer** renders the standard link as a clickable URL
- **No viewer at all** — the files are plain markdown, readable in any text editor

You get the best of all worlds without committing to any single ecosystem.

## Obsidian Integration

Each topic sub-wiki has its own `.obsidian/` config and can be opened as an independent vault:

```
open ~/wiki/topics/dementia/     # Open in Obsidian — focused graph for one topic
```

The global hub (`~/wiki/`) does NOT have `.obsidian/` to avoid nested vault confusion. If you want a full cross-topic view, open `~/wiki/` manually in Obsidian and let it create its own config.

What works out of the box:

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
