```
██╗     ██╗     ███╗   ███╗    ██╗    ██╗██╗██╗  ██╗██╗
██║     ██║     ████╗ ████║    ██║    ██║██║██║ ██╔╝██║
██║     ██║     ██╔████╔██║    ██║ █╗ ██║██║█████╔╝ ██║
██║     ██║     ██║╚██╔╝██║    ██║███╗██║██║██╔═██╗ ██║
███████╗███████╗██║ ╚═╝ ██║    ╚███╔███╔╝██║██║  ██╗██║
╚══════╝╚══════╝╚═╝     ╚═╝     ╚══╝╚══╝ ╚═╝╚═╝  ╚═╝╚═╝
```

[github.com/nvk/llm-wiki](https://github.com/nvk/llm-wiki)

LLM-compiled knowledge bases for any AI agent. Parallel multi-agent research, thesis-driven investigation, source ingestion, wiki compilation, querying, and artifact generation. Ships as a Claude Code plugin, an OpenAI Codex plugin, or a portable AGENTS.md for any other LLM agent. Obsidian-compatible.

## Changelog

**v0.3.0** — **Parallel Research & Human-Readable Lint.** New `--plan` flag for `/wiki:research` decomposes a topic into 3-5 independent research paths, presents the plan for confirmation, then dispatches all paths as parallel agent groups. Parallel ingest with path-prefixed raw files (no collisions), sequential compilation for cross-path synthesis. Extends `.research-session.json` with `mode` and `paths` fields (backward-compatible). Lint reports now lead with plain-English descriptions instead of internal check codes. C4 extended to catch broken inline body links. Test counter bug fixed — all 86 assertions now run.

**v0.2.1** — **Codex packaging.** Repo-local Codex plugin (`plugins/llm-wiki/`) and marketplace entry alongside the Claude plugin — same wiki-manager skill, two thin packaging layers. References are a single source of truth: the Codex tree symlinks into `claude-plugin/skills/wiki-manager/references/`. `./scripts/sync-codex-plugin.sh` regenerates the mirror; `tests/test-codex-sync.sh` catches drift inside the agent's own test loop with self-healing fix instructions. `tests/test-plugin-validate.sh` extended with 19 checks for symlink integrity, Codex manifests, and `agents/openai.yaml`.

**v0.2.0t** — **Tests.** Three-layer test suite: structural validation (84 assertions, no LLM, runs in seconds), behavioral evals via Promptfoo with Claude Agent SDK, and GitHub Actions CI workflow. Golden wiki fixture with 11 defect variants (one per lint rule) for negative testing. `CLAUDE.md` dev guide added.

**v0.2.0** — **Nice Cleanup.** Lint is the migration — `lint --fix` heals misplaced files and legacy layouts automatically. No migrate command needed. Projects simplified — `_project.md` manifest → plain `WHY.md`. Focus sessions removed. Thesis folded into research — `/wiki:research --mode thesis "<claim>"` replaces `/wiki:thesis`. Same logic, no duplication. Old command still works as shim. Hub resolution hardened — `resolved_path` cached in config, symlink recommended for iCloud. Tilde expansion runs at most once. −8% plugin size (3,933 → 3,610 lines) with zero rationale loss.

**v0.1.1** — **Project-aware lint and compile.** `/wiki:lint` now validates projects (manifest frontmatter, derived-content delimiters, frontmatter presence and match, member freshness, slug format) and surfaces migration candidates in existing wikis (loose binaries, sibling binary pairs, version families, and topical clusters). `--fix` regenerates stale manifest Members sections, backfills missing frontmatter, and rebuilds `output/_index.md` as a projects-aware listing. `/wiki:compile` regenerates project manifests as a best-effort tail step and steers new outputs with binary siblings into project folders from the start. Completes the v0.1.0 projects architecture.

**v0.1.0** — **Projects.** Group related outputs into project folders under `output/projects/<slug>/`. `/wiki:project` command with `new`, `list`, `show`, `add`, `archive` subcommands. `/wiki:research` and `/wiki:ingest` accept `--project <slug>`. Fuzzy router recognizes project intents.

## Install

**Claude Code** (native plugin):
```bash
claude plugin install wiki@llm-wiki
```

**OpenAI Codex** (repo-local plugin):

Quickstart (recommended, project-local):
```bash
git clone https://github.com/nvk/llm-wiki.git
cd llm-wiki
./scripts/bootstrap-codex-plugin.sh --scope project --verify
```

This does two things:
- registers this checkout as the `llm-wiki-local` marketplace in your selected Codex home
- writes a managed `@wiki` enable block to `.codex/config.toml` in the current project

If the verify step prints `PENDING`, Codex has the marketplace and config but still wants the interactive `/plugins` enable/materialization step for the first local install. Open `/plugins`, enable `LLM Wiki`, restart Codex if needed, then rerun `./scripts/verify-codex-plugin.sh --scope project`.

Manual `/plugins` install:
```bash
codex plugin marketplace add /absolute/path/to/llm-wiki
# Then open /plugins in Codex, enable "LLM Wiki", and invoke it as @wiki
```

Troubleshooting:
- Project scope requires a trusted project. If `.codex/config.toml` exists but `@wiki` does not resolve, trust the project and rerun `./scripts/verify-codex-plugin.sh --scope project`.
- If the helper reports that `llm-wiki-local` already points at another checkout, Codex already has a conflicting local marketplace entry in this `HOME`. Remove/re-add that marketplace or use the checkout that already owns it.
- A fresh local install may need one interactive `/plugins` enable before headless verification works. The verify script reports this as `PENDING`, not a silent failure.
- Restart Codex after changing config if an existing session does not pick up the new plugin state.
- If `~/.codex/config.toml` is symlinked into dotfiles and user scope writes fail, use `--scope project` instead or make the target writable.
- If you run Codex under a sandbox wrapper like `nono`, Codex needs its own profile allowances for `~/.codex`, any symlink targets, and the wiki data paths.
- The Codex plugin lives at `plugins/llm-wiki/` and is a thin wrapper around the same wiki-manager skill.

**OpenAI Codex / Any LLM Agent** (idea file):
```bash
# Copy AGENTS.md into your agent's context or project root
cp AGENTS.md ~/your-project/AGENTS.md
```

The `AGENTS.md` file contains the complete wiki protocol as a single portable document — works with any LLM agent that can read/write files and search the web.

## Claude-First, Codex-Compatible

If Claude Code is the principal user, do not try to make one plugin manifest serve both runtimes. Keep one shared behavior layer and two thin packaging layers:

- `claude-plugin/` is the primary distribution target and UX surface.
- `claude-plugin/skills/wiki-manager/` is the behavioral source of truth.
- `plugins/llm-wiki/` is the Codex packaging target.
- `.agents/plugins/marketplace.json` makes the Codex plugin installable from this repo.

The Codex plugin should stay generated, not hand-maintained. Rebuild it from the Claude source of truth with:

```bash
./scripts/sync-codex-plugin.sh
```

That script:

- copies `claude-plugin/skills/wiki-manager/SKILL.md` into the Codex tree and reapplies a small list of Codex-specific wording patches
- (re)creates `plugins/llm-wiki/skills/wiki-manager/references` as a **symlink** to `claude-plugin/skills/wiki-manager/references` — references are runtime-neutral and shared verbatim, no copy
- recreates `agents/openai.yaml` for Codex UI metadata
- syncs the Codex plugin version to match `claude-plugin/.claude-plugin/plugin.json`

Drift between the two trees is caught by `./tests/test-codex-sync.sh`, which runs the sync script and fails (with a self-healing fix instruction) if `plugins/` differs from `HEAD`. This runs alongside the other structural tests, so any LLM following the test-before-done rule catches a missed sync inside its own loop.

Practical rule: design workflows first for Claude commands and behavior, but keep the underlying knowledge model and references runtime-neutral. The Codex wrapper should adapt invocation and metadata, not fork the wiki logic.

## Upgrade

**Claude Code** — if `claude plugin update` pulls the latest correctly:
```bash
claude plugin update wiki@llm-wiki
# Restart Claude Code to apply
```

If the update command doesn't pick up the new version (stale marketplace cache), sync manually from the repo:
```bash
# Clone or pull the latest
git clone https://github.com/nvk/llm-wiki.git  # or: git -C ~/llm-wiki pull

# Sync plugin files to Claude Code's plugin cache
REPO=~/llm-wiki/claude-plugin
DEST=~/.claude/plugins/cache/llm-wiki/wiki
VERSION=$(grep '"version"' "$REPO/.claude-plugin/plugin.json" | grep -o '[0-9.]*')
rm -rf "$DEST"/*
mkdir -p "$DEST/$VERSION"
cp -R "$REPO/.claude-plugin" "$REPO/commands" "$REPO/skills" "$DEST/$VERSION/"

# Restart Claude Code to apply
```

**Codex** — pull the repo and reinstall from the local marketplace:
```bash
git -C ~/llm-wiki pull   # or clone if you don't have it yet
cd ~/llm-wiki
./scripts/bootstrap-codex-plugin.sh --scope project --verify
```

The Codex plugin is generated from the same Claude source — `plugins/llm-wiki/`'s `references/` is a symlink into `claude-plugin/skills/wiki-manager/references/`, so updates land identically across both runtimes. If `--verify` reports `PENDING`, finish the first-time enable in `/plugins` and rerun the verify command.

**AGENTS.md** — just pull the latest and replace:
```bash
curl -sL https://raw.githubusercontent.com/nvk/llm-wiki/master/AGENTS.md > ~/your-project/AGENTS.md
```

Check your installed version:
- Claude Code: look for the version in `/wiki` status output or check `~/.claude/plugins/installed_plugins.json`
- Codex: run `./scripts/verify-codex-plugin.sh --scope project` (or `--scope user`) and confirm the resolved skill path points at this repo
- If the verify script reports `PENDING`, finish the first-time enable in `/plugins` and rerun it

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
/wiki:query --resume                              # Where did I leave off?
/wiki add https://example.com/article             # Fuzzy router detects URL → ingest
/wiki what do we know about CRISPR?               # Fuzzy router detects question → query
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
| `/wiki <natural language>` | Fuzzy intent router — say what you want and it routes to the right subcommand |
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
| `/wiki:query <terms> --list` | Find content by keyword, tag, or category (replaces old `/wiki:search`) |
| `/wiki:query --resume` | Reload context after a session break — recent activity, stats, last-updated articles |
| `/wiki:plan <goal>` | Generate wiki-grounded implementation plan (interview → gap research → phased plan) |
| `/wiki:plan <goal> --quick` | Plan from wiki content only — skip interview and gap research |
| `/wiki:plan <goal> --format rfc\|adr\|spec` | Output as RFC, ADR, or tech spec instead of roadmap |
| `/wiki:research <topic>` | 5 parallel agents: academic, technical, applied, news, contrarian |
| `/wiki:research <topic> --new-topic` | Create a topic wiki and start researching — works from any directory |
| `/wiki:research <topic> --min-time 1h` | Keep researching in rounds until time budget is spent |
| `/wiki:research <topic> --plan` | Decompose into 3-5 parallel paths, confirm, then dispatch all at once |
| `/wiki:research <topic> --deep` | 8 agents: adds historical, adjacent, data/stats |
| `/wiki:research <topic> --retardmax` | 10 agents: skip planning, max speed, ingest aggressively |
| `/wiki:thesis <claim>` | Thesis-driven research: evidence for + against → verdict |
| `/wiki:thesis <claim> --min-time 1h` | Multi-round thesis investigation with anti-confirmation-bias |
| `/wiki:lint` | Run health checks on the wiki |
| `/wiki:lint --fix` | Auto-fix structural issues |
| `/wiki:lint --deep` | Web-verify facts and suggest improvements |
| `/wiki:output <type>` | Generate: summary, report, study-guide, slides, timeline, glossary, comparison |
| `/wiki:output <type> --retardmax` | Ship it now — rough but comprehensive, iterate later |
| `/wiki:assess <path>` | Assess a repo against wiki research + market. Gap analysis. |
| `/wiki:assess <path> --retardmax` | Wide net — adds adjacent fields and failure analysis |

All commands accept `--wiki <name>` to target a specific topic wiki and `--local` to target the project wiki. Commands that generate content (`query`, `output`, `plan`) also accept `--with <wiki>` to load supplementary wikis as cross-wiki context — e.g., `--with article-writing` applies writing craft knowledge when generating output from a domain wiki.

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
| `--plan` | Decompose into 3-5 parallel research paths, confirm, then dispatch all paths simultaneously. Parallel ingest, sequential compile. |
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
| List | `--list` | Returns ranked article list instead of synthesized answer. Supports `--tag` and `--category` filters. |

## Credits

- [Andrej Karpathy](https://x.com/karpathy) — the [LLM wiki concept](https://x.com/karpathy/status/2039805659525644595) and [idea file](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
- [Elisha Long](https://www.retardmaxx.com/) — retardmaxxing philosophy (act first, think later)
- [tobi/qmd](https://github.com/tobi/qmd) — recommended local search engine for scaling beyond ~100 articles
- [rvk7895/llm-knowledge-bases](https://github.com/rvk7895/llm-knowledge-bases) — prior art in Claude Code wiki plugins

## License

MIT License. Copyright (c) 2026 nvk.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files, to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, subject to the following conditions: the above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
