```
 __ __                                __ __       __ 
|  \  \                              |  \  \     |  \
| ▓▓ ▓▓______ ____       __   __   __ \▓▓ ▓▓   __ \▓▓
| ▓▓ ▓▓      \    \     |  \ |  \ |  \  \ ▓▓  /  \  \
| ▓▓ ▓▓ ▓▓▓▓▓▓\▓▓▓▓\    | ▓▓ | ▓▓ | ▓▓ ▓▓ ▓▓_/  ▓▓ ▓▓
| ▓▓ ▓▓ ▓▓ | ▓▓ | ▓▓    | ▓▓ | ▓▓ | ▓▓ ▓▓ ▓▓   ▓▓| ▓▓
| ▓▓ ▓▓ ▓▓ | ▓▓ | ▓▓    | ▓▓_/ ▓▓_/ ▓▓ ▓▓ ▓▓▓▓▓▓\| ▓▓
| ▓▓ ▓▓ ▓▓ | ▓▓ | ▓▓     \▓▓   ▓▓   ▓▓ ▓▓ ▓▓  \▓▓\ ▓▓
 \▓▓\▓▓\▓▓  \▓▓  \▓▓      \▓▓▓▓▓\▓▓▓▓ \▓▓\▓▓   \▓▓\▓▓
```

[github.com/nvk/llm-wiki](https://github.com/nvk/llm-wiki)

LLM-compiled knowledge bases for any AI agent. Parallel multi-agent research, thesis-driven investigation, source ingestion, wiki compilation, querying, and artifact generation. Ships as a Claude Code plugin or a portable AGENTS.md for Codex and others. Obsidian-compatible.

## What's New in v0.0.11

**Source Retraction** — cleanly remove regretted sources and their downstream effects:

- **`/wiki:retract`** — new command that handles the full blast radius: identifies all compiled articles referencing a source, removes metadata references, flags inline claims with retraction markers, deletes the raw source, and updates all indexes.
- **`--recompile`** flag rewrites affected article sections from remaining sources, removing retraction markers automatically.
- **`--dry-run`** shows the blast radius without making changes.
- **New lint rule C4b** (Source Provenance): catches dangling source references and unresolved retraction markers.
- Every retraction is logged permanently with the reason.

## What's New in v0.0.10

**Research Quality & Resilience** — 5 improvements backed by empirical research from the agentic AI knowledge base:

1. **Session Registry** — Multi-round research (`--min-time`) now persists state to `.research-session.json`. If interrupted, resume from the last completed round instead of starting over.
2. **Subagent Prompt Template** — Standardized prompt structure (Objective/Context/Constraints/Deliverables) for all research agents. "Most sub-agent failures aren't execution failures — they're invocation failures."
3. **Credibility Critic** — New Phase 2b: independent credibility assessment of sources before ingestion. Scores peer-review status, recency, author authority, and bias. Prevents the "fox guarding the henhouse" problem.
4. **Progress Scoring** — Each round now produces a 0-100 progress score. Enables principled termination (>=80 = quality ceiling) and low-yield detection (<40 = change strategy).
5. **Plan Reflection** — Explicit reflection step between rounds that re-evaluates the overall research direction, not just picks gaps. Scores gaps by impact x feasibility x specificity. Catches 34% more cross-topic connections.

## Install

**Claude Code** (native plugin):
```
/install-plugin github:nvk/llm-wiki
```

**OpenAI Codex / Any LLM Agent** (idea file):
```
# Copy AGENTS.md into your agent's context or project root
cp AGENTS.md ~/your-project/AGENTS.md
```

The `AGENTS.md` file contains the complete wiki protocol as a single portable document — works with any LLM agent that can read/write files and search the web.

> **New to a topic? One command, from anywhere:**
> ```
> /wiki:research "gut microbiome" --new-topic --min-time 1h
> ```
> Creates a topic wiki, launches parallel agents, and keeps researching for an hour — drilling into subtopics each round finds. Come back to a fully compiled wiki.

## Quick Start

```
/wiki:research "nutrition" --new-topic            # Create wiki + research in one shot
/wiki:research "gut-brain axis" --wiki nutrition   # Add more research to existing wiki
/wiki:research "fasting" --deep --min-time 2h     # 8 agents, keep going for 2 hours
/wiki:research "keto" --retardmax                 # 10 agents, max speed, ingest everything
/wiki:research "What makes long form articles go viral?" --new-topic  # Question → decompose → playbook
/wiki:thesis "fiber reduces neuroinflammation via SCFAs"  # Thesis-driven: evidence for + against → verdict
/wiki:thesis "cold exposure upregulates BDNF" --min-time 1h  # Deep thesis investigation
/wiki:query "How does fiber affect mood?"         # Ask the wiki
/wiki:query "compare keto and mediterranean" --deep  # Deep cross-referenced answer
/wiki:ingest https://example.com/article          # Manually ingest a source
/wiki:ingest --inbox                              # Process files dropped in inbox/
/wiki:compile                                     # Compile any unprocessed sources
/wiki:output report --topic gut-brain             # Generate a report
/wiki:output slides --retardmax                   # Ship a rough slide deck NOW
/wiki:assess /path/to/my-app --wiki nutrition     # Gap analysis: repo vs wiki vs market
/wiki:lint --fix                                  # Clean up inconsistencies
```

## Commands

| Command | Description |
|---------|-------------|
| `/wiki` | Show wiki status, stats, and list all topic wikis |
| `/wiki init <name>` | Create a topic wiki at `~/wiki/topics/<name>/` |
| `/wiki init <name> --local` | Create a project-local wiki at `.wiki/` |
| `/wiki:ingest <source>` | Ingest a URL, file path, or quoted text |
| `/wiki:ingest --inbox` | Process all files in the topic wiki's inbox/ |
| `/wiki:compile` | Compile new sources into wiki articles |
| `/wiki:compile --full` | Recompile everything from scratch |
| `/wiki:query <question>` | Q&A against the wiki (standard depth) |
| `/wiki:query <question> --quick` | Fast answer from indexes only |
| `/wiki:query <question> --deep` | Thorough — reads everything, checks raw + sibling wikis |
| `/wiki:research <topic>` | 5 parallel agents: academic, technical, applied, news, contrarian |
| `/wiki:research <topic> --new-topic` | Create a topic wiki and start researching — works from any directory |
| `/wiki:research <topic> --min-time 1h` | Keep researching in rounds until time budget is spent |
| `/wiki:research <topic> --deep` | 8 agents: adds historical, adjacent, data/stats |
| `/wiki:research <topic> --retardmax` | 10 agents: skip planning, max speed, ingest aggressively |
| `/wiki:thesis <claim>` | Thesis-driven research: evidence for + against → verdict |
| `/wiki:thesis <claim> --min-time 1h` | Multi-round thesis investigation with anti-confirmation-bias |
| `/wiki:search <terms>` | Find content by keyword or tag |
| `/wiki:lint` | Run health checks on the wiki |
| `/wiki:lint --fix` | Auto-fix structural issues |
| `/wiki:lint --deep` | Web-verify facts and suggest improvements |
| `/wiki:output <type>` | Generate: summary, report, study-guide, slides, timeline, glossary, comparison |
| `/wiki:output <type> --retardmax` | Ship it now — rough but comprehensive, iterate later |
| `/wiki:assess <path>` | Assess a repo against wiki research + market. Gap analysis. |
| `/wiki:assess <path> --retardmax` | Wide net — adds adjacent fields and failure analysis |

All commands accept `--wiki <name>` to target a specific topic wiki and `--local` to target the project wiki.

## How It Works

### Architecture

```
~/wiki/                                 # Hub — lightweight, no content
├── wikis.json                          # Registry of all topic wikis
├── _index.md                           # Lists topic wikis with stats
├── log.md                              # Global activity log
└── topics/                             # Each topic is an isolated wiki
    ├── nutrition/                      # Example topic wiki
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
    ├── woodworking/                    # Another topic wiki
    └── ...
```

The hub is just a registry — no content directories, no `.obsidian/`. All content lives in topic sub-wikis with isolated indexes and articles. Queries stay focused. The multi-wiki peek finds overlap across topics when relevant.

### The Flow

1. **Research** a topic — parallel agents search the web, ingest sources, and compile articles in one command
2. **Ingest** additional sources — URLs, files, text, tweets (via Grok MCP), or bulk via inbox
3. **Compile** raw sources into synthesized wiki articles with cross-references and confidence scores
4. **Query** the wiki — quick (indexes), standard (articles), or deep (everything)
5. **Assess** a repo against the wiki — gap analysis: what aligns, what's missing, what the market offers
6. **Lint** for consistency — broken links, missing indexes, orphan articles
7. **Output** artifacts — summaries, reports, slides — filed back into the wiki

### Key Design

- **One topic, one wiki** — each research area gets its own sub-wiki with isolated indexes. No cross-topic noise.
- **Parallel research agents** — 5 standard, 8 deep, 10 retardmax. Each agent searches from a different angle.
- **`_index.md` navigation** — every directory has an index. Claude reads indexes first, never scans blindly.
- **Articles are synthesized**, not copied — they explain, contextualize, cross-reference.
- **Raw is immutable** — once ingested, sources are never modified.
- **Multi-wiki aware** — queries peek at sibling wiki indexes for overlap.
- **Dual-linking** — both `[[wikilinks]]` (Obsidian) and standard markdown links on every cross-reference. Works everywhere.
- **Confidence scoring** — articles rated high/medium/low based on source quality and corroboration.
- **Structural guardian** — auto-checks wiki integrity after operations, fixes trivial issues silently.
- **Activity log** — `log.md` tracks every operation, append-only, grep-friendly.
- **Zero dependencies** — runs entirely on Claude Code built-in tools.

## Research Modes

| Mode | Flag | Agents | Style |
|------|------|--------|-------|
| Standard | *(default)* | 5 | Academic, technical, applied, news, contrarian |
| Deep | `--deep` | 8 | Adds historical, adjacent fields, data/stats |
| Retardmax | `--retardmax` | 10 | Adds rabbit-hole agents. Skip planning, cast widest net, ingest aggressively, compile fast. Lint later. |

**Smart input detection** — `/wiki:research` auto-detects whether you're passing a topic or a question:

| Input | Detected as | Behavior |
|-------|-------------|----------|
| `"nutrition"` | Topic | Standard research — explore the field |
| `"What makes articles go viral?"` | Question | Decompose into sub-questions → one agent per sub-question → synthesize → generate playbook → suggest theses |

Question mode produces a **playbook** (actionable output artifact) and suggests **testable theses** derived from the findings.

**Modifiers** (combine with any mode):

| Flag | What it does |
|------|-------------|
| `--new-topic` | Create a topic wiki from the research topic and start immediately. Works from any directory. |
| `--min-time <duration>` | Keep running research rounds until the time budget is spent (`30m`, `1h`, `2h`, `4h`). Each round drills into gaps the previous round found. |
| `--sources <N>` | Sources per round (default: 5, retardmax: 15) |

```
# The full combo — new topic, 2 hours of deep research, from anywhere
/wiki:research "CRISPR gene therapy" --new-topic --deep --min-time 2h
```

Retardmax mode is inspired by [Elisha Long's retardmaxxing philosophy](https://www.retardmaxx.com/) — act first, think later. The antidote to analysis paralysis. Works for both `/wiki:research` and `/wiki:output`.

## Thesis-Driven Research

Unlike open-ended research, `/wiki:thesis` starts with a specific claim and evaluates it:

```
/wiki:thesis "intermittent fasting reduces neuroinflammation via glymphatic upregulation"
```

**How it works:**
1. Decomposes the thesis into key variables, testable predictions, and falsification criteria
2. Launches parallel agents — but each agent has the thesis as a FILTER. Irrelevant sources get skipped (this prevents bloat)
3. Agents are split: **supporting**, **opposing**, **mechanistic**, **meta/review**, **adjacent** — balanced by design
4. Compiles evidence into wiki articles + a thesis file with evidence tables
5. Delivers a **verdict**: supported / partially supported / contradicted / insufficient evidence / mixed

**Anti-confirmation-bias**: When using `--min-time`, Round 2 automatically focuses harder on the WEAKER side of the evidence. If Round 1 found mostly supporting evidence, Round 2 hunts for counter-evidence.

**The thesis is the bloat filter.** Sources that don't relate to the claim's variables don't get ingested. Higher skip rate = tighter focus.

## Linking: Works Everywhere

Every cross-reference in the wiki uses dual-link format:

```markdown
[[gut-brain-axis|Gut-Brain Axis]] ([Gut-Brain Axis](../concepts/gut-brain-axis.md))
```

The wiki is **not locked into any tool**:

- **Obsidian** reads the `[[wikilink]]` — graph view, backlinks panel, quick-open
- **Claude Code** follows the standard `(relative/path.md)` link
- **GitHub/any markdown viewer** renders the standard link as clickable
- **No viewer at all** — plain markdown, readable in any text editor

## Obsidian Integration

Each topic wiki has its own `.obsidian/` config and can be opened as an independent vault:

```
open ~/wiki/topics/nutrition/     # Open in Obsidian — focused graph for one topic
```

The hub (`~/wiki/`) has no `.obsidian/` to avoid nested vault confusion. If you want a cross-topic view, open `~/wiki/` manually and let Obsidian create its own config.

What works out of the box:

- `.obsidian/` config created on init with sane defaults
- `[[wikilinks]]` power the graph view
- `aliases` in frontmatter enable search by alternate names
- `tags` in frontmatter are natively read
- `inbox/` works as a drop zone in both Obsidian and the CLI

Claude Code is the compiler. Obsidian is an optional viewer.

## Query Depths

| Depth | Flag | What it does |
|-------|------|-------------|
| Quick | `--quick` | Reads indexes only. Fastest. For simple lookups. |
| Standard | *(default)* | Reads relevant articles + full-text search. For most questions. |
| Deep | `--deep` | Reads everything, searches raw sources, peeks sibling wikis. For complex questions. |

## Credits

- [Andrej Karpathy](https://x.com/karpathy) — the [LLM wiki concept](https://x.com/karpathy/status/2039805659525644595) and [idea file](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
- [Elisha Long](https://www.retardmaxx.com/) — retardmaxxing philosophy (act first, think later)
- [tobi/qmd](https://github.com/tobi/qmd) — recommended local search engine for scaling beyond ~100 articles
- [rvk7895/llm-knowledge-bases](https://github.com/rvk7895/llm-knowledge-bases) — prior art in Claude Code wiki plugins

## License

MIT License. Copyright (c) 2026 nvk.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files, to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, subject to the following conditions: the above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
