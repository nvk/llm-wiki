```
██╗     ██╗     ███╗   ███╗    ██╗    ██╗██╗██╗  ██╗██╗
██║     ██║     ████╗ ████║    ██║    ██║██║██║ ██╔╝██║
██║     ██║     ██╔████╔██║    ██║ █╗ ██║██║█████╔╝ ██║
██║     ██║     ██║╚██╔╝██║    ██║███╗██║██║██╔═██╗ ██║
███████╗███████╗██║ ╚═╝ ██║    ╚███╔███╔╝██║██║  ██╗██║
╚══════╝╚══════╝╚═╝     ╚═╝     ╚══╝╚══╝ ╚═╝╚═╝  ╚═╝╚═╝
```

[github.com/nvk/llm-wiki](https://github.com/nvk/llm-wiki)

LLM-compiled knowledge bases for any AI agent. Parallel multi-agent research, collector catalogs, automated session capture, feedback curation, thesis-driven investigation, source ingestion, wiki compilation, truth-seeking audits, querying, and artifact generation. Ships as a Claude Code plugin, an OpenAI Codex plugin, an OpenCode instruction file, or a portable AGENTS.md for any other LLM agent. Obsidian-compatible.

---

[Install](#install) · [Quick Start](#quick-start) · [Commands](#commands) · [How It Works](#how-it-works) · [Research Modes](#research-modes) · [Thesis Research](#thesis-driven-research) · [Query Depths](#query-depths) · [Linking](#linking-works-everywhere) · [Obsidian](#obsidian-integration) · [Architecture](#claude-first-multi-runtime) · [Nono Sandbox](#nono-sandbox-permissions) · [Upgrade](#upgrade) · [Changelog](#changelog) · [Credits](#credits)

---

## Changelog

**v0.15.0** — **Topic guides.** Reframes `schema.md` as a human-owned topic guide, adds the friendlier `llm-wiki schema adopt` helper, keeps `schema migrate --apply` as a compatibility alias, and updates librarian docs to talk about conventions proposals instead of database-style schema migrations.

**v0.14.0** — **Default topic guides.** Adds advisory `schema.md` by default, safe adoption helpers for older wikis, proposal-only librarian convention updates, deterministic docs/lint checks, and clarifies the optional index/server layer as a rebuildable non-authoritative cache.

**v0.12.0** — **Feedback curator.** Captures high-signal corrections, preferences, approvals, and plan acceptance as redacted feedback candidates under `HUB/.sessions/feedback/`; ignores generic acknowledgements; adds review/manual-capture/promotion workflows; and keeps promotion into topic `raw/notes/` explicit.

**v0.11.1** — **Session helper compatibility.** Small hotfix so automated session capture works on Python 3.9/macOS system Python as well as newer Python runtimes.

**v0.11.0** — **Automated session capture.** Default-on redacted checkpoints under `HUB/.sessions/`, opt-out via `session disable`, compact context rehydration, explicit digest promotion, and a tested Codex hook bundle.

**v0.10.2** — **Collector production hardening.** Collection-family topic slugs now prefer kind-first names such as `memes-bitcoin`, the scale boundary treats 500 rows as large and 501+ as huge, and media downloads call out timeouts, file-size caps, content-type checks, and IPv4 retry.

## Install

**Claude Code** (native plugin):
```bash
claude plugin install wiki@llm-wiki
```

**OpenAI Codex** (marketplace plugin):

Install from GitHub:
```bash
codex plugin marketplace add nvk/llm-wiki
# Then open /plugins in Codex, enable "LLM Wiki", and use @wiki
```

Install from a local checkout with the managed bootstrap helper:
```bash
./scripts/bootstrap-codex-plugin.sh --scope user --verify
```

Or register the local checkout manually:
```bash
codex plugin marketplace add /absolute/path/to/llm-wiki
```

Canonical explicit invocation:
```text
@wiki research "hardware wallet threat models"
@wiki collect "bitcoin memes" --wiki memes-bitcoin
@wiki ingest https://example.com/article
@wiki audit --project coldcard-threat-model
@wiki session status
@wiki feedback list --unpromoted
@wiki session disable   # optional opt-out
@wiki ll "codex plugin install gotchas"
```

Upgrade:
```bash
codex plugin marketplace upgrade llm-wiki
```

Remove:
```bash
codex plugin marketplace remove llm-wiki
```

Troubleshooting:
- After installing the marketplace, open `/plugins` in Codex and enable "LLM Wiki" — first install requires the interactive enable step.
- `@wiki` is the canonical explicit entry point in Codex. Natural-language wiki requests can still auto-activate the skill.
- Restart Codex after changing config if an existing session does not pick up the new plugin state.
- If you run Codex under a sandbox wrapper like `nono`, see [Nono Sandbox Permissions](#nono-sandbox-permissions) — Codex needs r+w to `$HOME/.codex` for plugin install.

**OpenCode** (instruction file):

Add to your `opencode.json` (project-level or `~/.config/opencode/.opencode.json` for global):
```json
{
  "instructions": ["https://raw.githubusercontent.com/nvk/llm-wiki/master/plugins/llm-wiki-opencode/skills/wiki-manager/SKILL.md"],
  "permission": {
    "external_directory": {
      "~/.config/llm-wiki/**": "allow",
      "~/Library/Mobile Documents/com~apple~CloudDocs/wiki/**": "allow"
    }
  }
}
```

OpenCode fetches the URL fresh on every session start — no manual updates needed. If you prefer a local copy instead:
```bash
curl -sL https://raw.githubusercontent.com/nvk/llm-wiki/master/plugins/llm-wiki-opencode/skills/wiki-manager/SKILL.md > ~/.config/opencode/AGENTS.md
```

The `external_directory` permission is required because the wiki hub lives outside the project directory. Set the paths to match your hub location. Alternatively, use `--local` mode (`.wiki/` in the project) to skip permissions entirely.

Web search requires `export OPENCODE_ENABLE_EXA=1`.

**Pi** (instruction file — best for local models):

Pi's minimal system prompt (~1K tokens) leaves room for the full wiki skill on 32K context local models.

```bash
pi --instructions path/to/llm-wiki/plugins/llm-wiki-opencode/skills/wiki-manager/SKILL.md
```

With a local llama-server backend (no cloud API needed):
```bash
OPENAI_BASE_URL=http://127.0.0.1:8080/v1 OPENAI_API_KEY=local \
  pi --instructions path/to/llm-wiki/plugins/llm-wiki-opencode/skills/wiki-manager/SKILL.md
```

Pi uses the same OpenCode skill file — no separate packaging needed.

**Any LLM Agent** (idea file):
```bash
# Copy AGENTS.md into your agent's context or project root
cp AGENTS.md ~/your-project/AGENTS.md
```

The `AGENTS.md` file contains the complete wiki protocol as a single portable document — works with any LLM agent that can read/write files and search the web.

**Hermes** (plugin):

Drop the plugin directory into your Hermes plugins folder and restart Hermes:

```bash
git clone https://github.com/nvk/llm-wiki.git /tmp/llm-wiki
mkdir -p ~/.hermes/plugins
ln -s /tmp/llm-wiki/plugins/llm-wiki-hermes ~/.hermes/plugins/llm-wiki-hermes
```

Hermes auto-discovers the plugin: the five session-capture hooks and the `wiki`
tool activate immediately, and the wiki-manager skill enables agentic commands
(`research`, `query`, `collect`, `ingest`, `compile`, `audit`, `output`, …).
Hermes also proactively injects relevant wiki notes as memory on each user
prompt (toggle with `LLM_WIKI_HERMES_MEMORY=0` or `memory.inject: false` in
`HUB/.sessions/config.json`).

## Claude-First, Multi-Runtime

Claude Code is the principal user. Keep one shared behavior layer and thin packaging layers per runtime:

- `claude-plugin/` is the primary distribution target and UX surface.
- `claude-plugin/skills/wiki-manager/` is the behavioral source of truth.
- `plugins/llm-wiki/skills/wiki/` is the generated Codex packaging target behind `@wiki`.
- `plugins/llm-wiki-opencode/` is the OpenCode and Pi packaging target.
- `.agents/plugins/marketplace.json` makes the Codex plugin installable from this repo.
- `AGENTS.md` is the portable single-file protocol for any other LLM agent.

**Supported clients:**

| Client | Install method | System prompt size | Best for |
|--------|---------------|-------------------|----------|
| Claude Code | `claude plugin install wiki@llm-wiki` | ~22K tokens | Full agentic research, 200K context |
| Codex | `codex plugin marketplace add nvk/llm-wiki` | ~3K tokens | OpenAI ecosystem |
| OpenCode | `opencode.json` instructions | ~3K tokens | Multi-provider, Go binary |
| Pi | `--instructions SKILL.md` | ~1K tokens | Local models, minimal overhead |
| Any agent | Copy `AGENTS.md` to project | Varies | Universal fallback |
| Hermes | `~/.hermes/plugins/llm-wiki-hermes` | ~3K tokens | NousResearch agent |

Both runtime mirrors are generated, not hand-maintained. Rebuild from the Claude source of truth:

```bash
./scripts/sync-codex-plugin.sh      # regenerates plugins/llm-wiki/
./scripts/sync-opencode-plugin.sh   # regenerates plugins/llm-wiki-opencode/
```

Each sync script:

- copies `claude-plugin/skills/wiki-manager/SKILL.md` into the target tree and reapplies a small list of runtime-specific wording patches
- copies `references/` from the Claude source — references are runtime-neutral and shared verbatim (previously a symlink, now a real copy so Codex marketplace caching works)
- (Codex only) recreates `agents/openai.yaml` for Codex UI metadata and syncs the plugin version

Drift is caught by `./tests/test-codex-sync.sh` and `./tests/test-opencode-sync.sh`, which run the sync scripts and fail (with self-healing fix instructions) if the generated directories differ from `HEAD`.

Practical rule: design workflows first for Claude commands and behavior, but keep the underlying knowledge model and references runtime-neutral. Runtime wrappers adapt invocation and metadata, not wiki logic.

## Nono Sandbox Permissions

If you run any AI coding agent inside a [nono](https://github.com/always-further/nono) sandbox, the wiki needs filesystem access beyond the default profile.

### Claude Code / OpenCode

```json
{
  "extends": "claude-code",
  "policy": {
    "add_allow_read": [
      "$HOME/.config/llm-wiki"
    ],
    "add_allow_readwrite": [
      "$HOME/Library/Mobile Documents/com~apple~CloudDocs/wiki"
    ]
  }
}
```

Replace `"extends": "claude-code"` with `"opencode"` for OpenCode.

### Codex

Codex needs r+w to its own `$HOME/.codex` directory for plugin install, marketplace cache, state, and skill registration:

```json
{
  "extends": "codex",
  "policy": {
    "add_allow_read": [
      "$HOME/.config/llm-wiki"
    ],
    "add_allow_readwrite": [
      "$HOME/.codex",
      "$HOME/Library/Mobile Documents/com~apple~CloudDocs/wiki"
    ]
  }
}
```

### Path reference

| Path | Access | Purpose |
|------|--------|---------|
| `$HOME/.config/llm-wiki` | read | Hub path config — checked first during resolution (v0.4.2+) |
| Wiki data dir | readwrite | The wiki itself — use the actual path, not `$HOME/wiki` (see below) |
| `$HOME/.codex` | readwrite | Codex only — plugin cache, skills, state, marketplace temp files |

### Hub resolution and `~/wiki`

Hub resolution checks `~/.config/llm-wiki/config.json` first and only falls back to `~/wiki` when no config exists. If your wiki lives on iCloud or any non-default path, set the config and you don't need `$HOME/wiki` in the sandbox at all:

```bash
# Set once — agents will resolve from config, never touch ~/wiki
/wiki config hub-path "~/Library/Mobile Documents/com~apple~CloudDocs/wiki"
```

Use a portable `hub_path` with `~` for iCloud-shared hubs. Older configs may
contain `resolved_path`; llm-wiki treats it as a fallback cache because an
absolute `/Users/<name>/...` path from one Mac will not be valid on another.
The shared `wikis.json` should likewise store hub topic paths as
`topics/<slug>`, not absolute user-home paths.

If you prefer `~/wiki` as a symlink to iCloud, nono's Seatbelt follows symlinks — the target path must be allowed, not the symlink itself.

### Diagnosing access issues

Without the right permissions, Seatbelt or macOS privacy controls can block file
access. A useful diagnostic pattern is: `stat` succeeds for the iCloud wiki path,
but reading `wikis.json` or listing `topics/` fails with `Operation not
permitted`. That means the configured `hub_path` is correct; grant Full Disk
Access or iCloud Drive access to the exact app launching the agent, restart it,
and do not switch to a machine-local `resolved_path` or `~/wiki` fallback. Use
`nono why` to diagnose sandbox rules:

```bash
nono why --path ~/.config/llm-wiki --op read
nono why --path ~/Library/Mobile\ Documents/com~apple~CloudDocs/wiki --op readwrite
```

**OpenCode** also needs the `external_directory` permission in `opencode.json` (see [Install](#install)) — nono and OpenCode have independent sandboxes that both need the same paths allowed.

## Upgrade

Agents and sandboxed sessions should use GitHub CLI web login with HTTPS git
transport, not SSH. This avoids SSH host-key prompts and `known_hosts` writes
inside nono:

```bash
gh auth login --web --git-protocol https
gh auth setup-git
```

**Claude Code** — if `claude plugin update` pulls the latest correctly:
```bash
git -C ~/.claude/plugins/marketplaces/llm-wiki remote set-url origin https://github.com/nvk/llm-wiki.git
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

**Codex** — upgrade from the marketplace:
```bash
codex plugin marketplace upgrade llm-wiki
```

**OpenCode** — if using the GitHub URL in `instructions`, updates are automatic (fetched every session). If using a local copy:
```bash
curl -sL https://raw.githubusercontent.com/nvk/llm-wiki/master/plugins/llm-wiki-opencode/skills/wiki-manager/SKILL.md > ~/.config/opencode/AGENTS.md
```

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
/wiki:collect "bitcoin memes" --wiki memes-bitcoin  # Find, dedupe, download media, catalog, and optionally inventory artifacts
/wiki:collect "bitcoin memes" --scale medium --media reference --inventory corpus  # Catalog media without binary downloads
/wiki:query "How does fiber affect mood?"         # Ask the wiki
/wiki:query "compare keto and mediterranean" --deep  # Deep cross-referenced answer
/wiki:query --resume                              # Where did I leave off?
/wiki add https://example.com/article             # Fuzzy router detects URL → ingest
/wiki what do we know about CRISPR?               # Fuzzy router detects question → query
/wiki:ingest https://example.com/article          # Manually ingest a source
/wiki:ingest --inbox                              # Process files dropped in inbox/
/wiki:ingest-collection https://github.com/bitcoin/bips --wiki bitcoin  # Bulk import spec repos
/wiki:ingest-collection https://dump.bitcoin.it/dump_20260429_en.xml.bz2 --wiki bitcoin  # Import MediaWiki dumps
/wiki:ingest-collection messages.csv --adapter csv-messages --wiki bitcoin  # Split message archives
/wiki:ingest-collection "https://example.com/*" --adapter wayback-cdx --from 20100101 --to 20200101  # Import archived snapshots
/wiki:inventory add ingest-candidate "Bitcointalk archive" --wiki bitcoin  # Track source queues and next actions
/wiki:inventory add item "TRX-4M ring and pinion" --wiki trx4m-1-18  # Track actual parts, tools, hosts, or assets
/wiki:inventory list --view actions --limit 10   # Compact chat table of current inventory next actions
/wiki:inventory scan-outputs --dry-run          # Preview queues/backlogs before any inventory pivot
/wiki:dataset add "Bitcointalk Temporal Graph" --location https://figshare.com/articles/dataset/BitcoinTemporalGraph/26305093 --wiki bitcoin  # Index data that stays external
/wiki:dataset list --view schema --limit 10      # Compact chat table of dataset schema/readiness state
/wiki:dataset scan-outputs --dry-run            # Find legacy data reports that could become dataset manifests
/wiki:archive topic old-interest --reason "No longer active"  # Preserve a topic but hide it from normal context
/wiki:archive list --archived                   # Show active and archived topic wikis
/wiki:archive restore old-interest              # Bring an archived topic back
/wiki:compile                                     # Compile any unprocessed sources
/wiki:audit --project gut-brain-playbook          # Truth-seeking audit across outputs + wiki + fresh research
/wiki:output report --topic gut-brain             # Generate a report
/wiki:output slides --retardmax                   # Ship a rough slide deck NOW
/wiki:assess /path/to/my-app --wiki nutrition     # Gap analysis: repo vs wiki vs market
/wiki:lint --fix                                  # Clean up inconsistencies
```

When working from this repository checkout, you can also run deterministic
checks without an agent:

```bash
./scripts/llm-wiki lint /path/to/wiki
./scripts/llm-wiki lint --fix /path/to/wiki
./scripts/llm-wiki schema status /path/to/wiki
./scripts/llm-wiki schema adopt /path/to/wiki          # add starter topic guide
./scripts/llm-wiki schema adopt --dry-run /path/to/wiki # preview without writing
./scripts/llm-wiki archive --hub /path/to/hub topic old-interest --reason "No longer active"
./scripts/llm-wiki archive --hub /path/to/hub list --archived
./scripts/llm-wiki archive --hub /path/to/hub restore old-interest
./scripts/llm-wiki-session --hub /path/to/hub status
./scripts/llm-wiki-session --hub /path/to/hub disable   # optional opt-out
./scripts/llm-wiki-session --hub /path/to/hub enable --mode balanced --tool-events 50
./scripts/llm-wiki-session --hub /path/to/hub rehydrate --cwd "$PWD"
./scripts/llm-wiki-session --hub /path/to/hub feedback list --unpromoted
```

This local helper covers structural checks and safe migrations that do not
require an LLM. The agentic `/wiki:lint` workflow remains the full protocol for
editorial and deep verification passes. The local schema helper creates only a
starter advisory topic guide (`schema.md`); run librarian conventions advice
for established wikis before adopting topic-specific vocabulary. The local archive helper
performs the deterministic folder move plus `wikis.json`, hub index, and log
updates.

## Commands

| Command | Description |
|---------|-------------|
| `/wiki <natural language>` | Fuzzy intent router — say what you want and it routes to the right subcommand |
| `/wiki` | Show wiki status, stats, and list all topic wikis |
| `/wiki init <name>` | Create a topic wiki at `~/wiki/topics/<name>/` |
| `/wiki init <name> --local` | Create a project-local wiki at `.wiki/` |
| `/wiki:ingest <source>` | Ingest a URL, file path, PDF, or quoted text |
| `/wiki:ingest --inbox` | Process all files in the topic wiki's inbox/ |
| `/wiki:ingest-collection <source>` | Bulk-ingest Git doc repos, BIP-style proposal sets, MediaWiki dumps/API sites, message archives, or Wayback CDX snapshots |
| `/wiki:ingest-collection <source> --adapter git\|mediawiki-dump\|mediawiki-api\|csv-messages\|wayback-cdx` | Force a collection adapter |
| `/wiki:ingest-collection <source> --limit <N> --dry-run` | Preview or cap a large collection import |
| `/wiki:collect "<things>"` | Find, dedupe, and catalog artifacts, examples, resources, media, memes, tools, entities, or source candidates |
| `/wiki:collect "<things>" --scale tiny\|small\|medium\|large\|huge` | Control write behavior by operational scale, not just row count |
| `/wiki:collect "<things>" --media archive\|thumbnail\|reference` | Download/cache bounded originals by default; use thumbnail for previews or reference to opt out |
| `/wiki:collect "<things>" --inventory records` | Create per-item inventory records when the collected set is small enough to stay useful |
| `/wiki:collect "<things>" --inventory corpus` | Track a large, unstable, or media-heavy collection as one corpus record linked to the catalog output |
| `/wiki:inventory list` | List durable tracking records as compact chat-friendly tables or bullets |
| `/wiki:inventory list --view actions` | Show current inventory next actions without dumping full records |
| `/wiki:inventory add <kind> "title"` | Add an inventory record after checking that inventory is the right layer |
| `/wiki:inventory save-view "name"` | Save a derived reusable table/list under `inventory/views/` |
| `/wiki:inventory scan-outputs --dry-run` | Find old queue/backlog outputs and preview sample records before migration |
| `/wiki:inventory migrate-output <path> --apply` | Additively create inventory records from a legacy output; never moves or deletes the output |
| `/wiki:dataset list` | List dataset manifests as compact chat-friendly tables or bullets |
| `/wiki:dataset list --view schema` | Show schema/readiness state without opening samples or data |
| `/wiki:dataset add "title" --location <path-or-url>` | Add a dataset manifest without copying data into the wiki |
| `/wiki:dataset profile <slug> --dry-run` | Preview lightweight profiling of size, format, headers, or schema observations |
| `/wiki:dataset migrate-output <path> --apply` | Additively create dataset manifests from a legacy output; never moves or copies the underlying data |
| `/wiki:archive list [--archived]` | List active topic wikis and optionally archived topic wikis |
| `/wiki:archive topic <slug> --reason "why"` | Move a topic wiki to `topics/.archive/<slug>` and hide it from default context |
| `/wiki:archive restore <slug>` | Restore an archived topic wiki to active status |
| `/wiki:archive peek <query>` | Search archived topic indexes without reading archived articles |
| `/wiki:session status` | Show automated session-capture mode, root, and indexed session count |
| `/wiki:session disable` | Opt out of automated redacted session capture |
| `/wiki:session enable --mode balanced` | Re-enable or tune automated capture and soft rehydration |
| `/wiki:session capture` | Force a manual session digest checkpoint |
| `/wiki:session rehydrate` | Print compact context from matching session digests |
| `/wiki:session promote <id> --topic <slug>` | Promote a distilled digest into a topic raw note |
| `/wiki:feedback list --unpromoted` | Review high-signal user-feedback candidates captured from session hooks |
| `/wiki:feedback show <id>` | Inspect a candidate with distilled lesson, confidence, scope, and redacted preview |
| `/wiki:feedback promote <id> --topic <slug>` | Promote a selected feedback candidate into topic `raw/notes/` |
| `/wiki:compile` | Compile new sources into wiki articles |
| `/wiki:compile --full` | Recompile everything from scratch |
| `/wiki:query <question>` | Q&A against the wiki (standard depth) |
| `/wiki:query <question> --quick` | Fast answer from indexes only |
| `/wiki:query <question> --deep` | Thorough — reads everything, checks raw + sibling wikis |
| `/wiki:query <question> --include-archived` | Explicitly search/read archived material, with archived citations labeled |
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
| `/wiki:audit` | Umbrella trust audit: wiki, outputs, provenance, and fresh research when needed |
| `/wiki:audit --artifact <path>` | Audit one article or output artifact and follow its evidence chain |
| `/wiki:audit --project <slug>` | Audit one project's outputs and upstream wiki state |
| `/wiki:audit report` | Display the latest umbrella audit report |
| `/wiki:librarian` | Focused wiki maintenance: staleness and quality scan for the `wiki/` layer |
| `/wiki:librarian --article <path>` | Scan a single article |
| `/wiki:librarian scan --passes staleness,quality,conventions` | Generate topic-guide advice/proposals for established wikis without rewriting `schema.md` |
| `/wiki:librarian report` | Display the latest librarian scan report |
| `/wiki:refresh [<article-path>|--due]` | Re-check article sources for changed facts and offer human-gated updates |
| `/wiki:output <type>` | Generate: summary, report, study-guide, slides, timeline, glossary, comparison |
| `/wiki:output <type> --retardmax` | Ship it now — rough but comprehensive, iterate later |
| `/wiki:project new <slug> "goal"` | Group related outputs under `output/projects/<slug>/` with a plain `WHY.md` rationale |
| `/wiki:project list\|show\|add\|archive` | Manage output project folders without duplicating project state into frontmatter |
| `/wiki:retract <source-path> --reason "why"` | Remove a bad source, map blast radius, and flag downstream claims for review |
| `/wiki:ll` | Extract lessons learned from the current session into the wiki |
| `/wiki:ll --dry-run` | Preview extracted lessons without writing |
| `/wiki:ll --rules` | Also suggest CLAUDE.md / AGENTS.md rule additions |
| `/wiki:assess <path>` | Assess a repo against wiki research + market. Gap analysis. |
| `/wiki:assess <path> --retardmax` | Wide net — adds adjacent fields and failure analysis |

All commands accept `--wiki <name>` to target a specific topic wiki and `--local` to target the project wiki. Archived topic wikis are skipped by default; commands that support `--include-archived` require that explicit flag before reading or writing archived material. Commands that generate content (`query`, `output`, `plan`) also accept `--with <wiki>` to load supplementary wikis as cross-wiki context — e.g., `--with article-writing` applies writing craft knowledge when generating output from a domain wiki.

`/wiki:librarian` is the focused wiki-maintenance tool. `/wiki:audit` is broader and may perform fresh research to decide whether the current knowledge or generated outputs are still trustworthy.

## How It Works

### Architecture

```
~/wiki/                                 # Hub — lightweight, no content
├── wikis.json                          # Registry of all topic wikis
├── _index.md                           # Lists topic wikis with stats
├── log.md                              # Global activity log
├── .sessions/                          # Optional session capture + feedback candidates
└── topics/                             # Each topic is an isolated wiki
    ├── nutrition/                      # Example topic wiki
    │   ├── .obsidian/                  # Optional Obsidian vault config
    │   ├── inbox/                      # Drop zone for this topic
    │   ├── inventory/                  # Lazy: durable tracking records + derived views
    │   ├── datasets/                   # Lazy: manifests for large/external data
    │   ├── raw/                        # Immutable sources
    │   ├── wiki/                       # Compiled articles
    │   │   ├── concepts/
    │   │   ├── topics/
    │   │   └── references/
    │   ├── output/                     # Generated artifacts
    │   ├── _index.md
    │   ├── config.md
    │   ├── schema.md                  # Human-owned topic guide
    │   └── log.md
    ├── woodworking/                    # Another topic wiki
    ├── .archive/                       # Archived topic wikis, hidden by default
    └── ...
```

The hub is just a registry — no content directories, no `.obsidian/`. All content lives in topic sub-wikis with isolated indexes, articles, and a human-owned advisory topic guide (`schema.md`). Init creates the core wiki skeleton first; optional inventory and dataset layers are created when you use them. Queries stay focused. The multi-wiki peek finds overlap across topics when relevant.

### The Flow

1. **Research** a topic — parallel agents search the web, ingest sources, and compile articles in one command
2. **Ingest** additional sources — URLs, files, text, tweets (via Grok MCP), or bulk via inbox
3. **Collect** catalogs of discoverable things — examples, media, memes, tools, projects, entities, or source candidates — then optionally inventory them
4. **Inventory** items, candidates, entities, corpora, watch lists, and next actions that should persist; the agent tells you when inventory is the wrong layer
5. **Index datasets** that are too large for markdown — manifests, profiles, samples, and query recipes
6. **Archive** whole topic wikis that should stay preserved but quiet
7. **Compile** raw sources into synthesized wiki articles with cross-references and confidence scores
8. **Query** the wiki — quick (indexes), standard (articles), or deep (everything active, archived indexes separated)
9. **Session capture** — automatically preserve redacted Claude/Codex/OpenCode/Gemini/Hermes checkpoints under `.sessions/` and rehydrate future turns (Hermes additionally injects matching wiki notes as memory on each prompt)
10. **Feedback curator** — capture reviewable correction/preference/approval candidates under `.sessions/feedback/` and promote only what matters
11. **Lessons learned** — extract knowledge from the current session (errors, fixes, gotchas) into the wiki
12. **Assess** a repo against the wiki — gap analysis: what aligns, what's missing, what the market offers
13. **Lint** for consistency — broken links, missing indexes, orphan articles, archive registry drift
14. **Output** artifacts — summaries, reports, slides — filed back into the wiki

### Key Design

- **One topic, one wiki** — each research area gets its own sub-wiki with isolated indexes. No cross-topic noise.
- **Canonical collection slugs** — collection families use kind-first topic
  names such as `memes-bitcoin`, `memes-ethereum`, or `tools-bitcoin` so
  related catalogs group naturally as the hub grows.
- **Parallel research agents** — 5 standard, 8 deep, 10 retardmax. Each agent searches from a different angle.
- **Collector workflow** — search-driven catalogs for objects, media, and
  examples; saves a provenance map first, then inventories only the durable
  subset.
- **`_index.md` navigation** — every existing wiki-managed directory has an index. Claude reads indexes first, never scans blindly.
- **Articles are synthesized**, not copied — they explain, contextualize, cross-reference.
- **Raw is immutable** — once ingested, sources are never modified.
- **Multi-wiki aware** — queries peek at sibling wiki indexes for overlap.
- **Archive-aware** — archived topic wikis stay preserved under
  `topics/.archive/` but are hidden from default query/compile/research/collect/output
  and maintenance workflows.
- **Dual-linking** — both `[[wikilinks]]` (Obsidian) and standard markdown links on every cross-reference. Works everywhere.
- **Confidence scoring** — articles rated high/medium/low based on source quality and corroboration.
- **Structural guardian** — auto-checks wiki integrity after operations, fixes trivial issues silently.
- **Activity log** — `log.md` tracks every operation, append-only, grep-friendly.
- **Opinionated inventory** — durable tracking gets records; one-off sources stay
  ingest/query; large row-like data becomes datasets or collection ingests. Big
  pivots start with a sample table before records are written.
- **Media-safe catalogs** — bounded public binary media is cached under
  `output/assets/collect-<slug>/` by default; raw sources remain textual
  evidence, and large media sets become dataset manifests. Bulk downloads use
  timeouts, file-size caps, content-type checks, and IPv4 retry when needed.
- **Feedback is candidate memory** — corrections, preferences, approvals, and
  plan acceptance are saved as redacted candidates under `.sessions/feedback/`;
  generic acknowledgements are ignored, and promotion into topic notes is
  explicit.
- **Zero dependencies** — runs entirely on built-in tools (Claude Code, OpenCode, or Codex).

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

- `.obsidian/` config can be created on init with sane defaults
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
| Deep | `--deep` | Reads everything active, searches raw sources, peeks sibling wikis, and surfaces archived index matches separately. |
| List | `--list` | Returns ranked article list instead of synthesized answer. Supports `--tag` and `--category` filters. |

Archived topics are excluded from quick, standard, and list results unless you
pass `--include-archived`. Deep mode may show archived index hits, but it does
not cite archived material as active evidence without explicit inclusion.

## Credits

- [Andrej Karpathy](https://x.com/karpathy) — the [LLM wiki concept](https://x.com/karpathy/status/2039805659525644595) and [idea file](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
- [Elisha Long](https://www.retardmaxx.com/) — retardmaxxing philosophy (act first, think later)
- [tobi/qmd](https://github.com/tobi/qmd) — recommended local search engine for scaling beyond ~100 articles
- [rvk7895/llm-knowledge-bases](https://github.com/rvk7895/llm-knowledge-bases) — prior art in Claude Code wiki plugins

## License

MIT License. Copyright (c) 2026 nvk.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files, to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, subject to the following conditions: the above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
