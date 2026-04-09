---
description: "LLM wiki knowledge base — understands natural language. Say what you want (add a URL, ask a question, research a topic, resume work) and it routes to the right subcommand. Also handles init, status, and config."
argument-hint: "[<natural language request>] [init <topic-name> [--local]] [config hub-path [<path>]] [--wiki <name>]"
allowed-tools: Read, Write, Edit, Glob, Bash(ls:*), Bash(wc:*), Bash(mkdir:*), Bash(date:*), Bash(mv:*)
---

## Your task

First, resolve **HUB** by following the protocol in `references/hub-resolution.md` (check `~/wiki/` first, then config, expand leading `~` only, quote paths with spaces). Then check if a wiki exists by trying to read `HUB/_index.md` (global hub) and `.wiki/_index.md` (local).

You are the llm-wiki knowledge base manager. Read the skill at `skills/wiki-manager/SKILL.md` and structure reference at `skills/wiki-manager/references/wiki-structure.md` for full conventions.

Resolve which wiki to use:
1. If `--local` flag → `.wiki/` in current directory
2. If `--wiki <name>` flag → look up in `HUB/wikis.json`
3. If current directory has `.wiki/` → use it
4. Otherwise → HUB (hub — show status of all topic wikis)

---

### If $ARGUMENTS contains "init"

Initialize a new wiki. Parse arguments:
- `init <name>` → create topic wiki at `HUB/topics/<name>/`
- `init <name> --local` → create local wiki at `.wiki/` in current project
- `init` (no name) → ask: "What topic is this for?" Then create the topic wiki with their answer.

**A topic name is always required.** There is no bare global wiki — HUB is only a hub (wikis.json + _index.md + log.md). All content lives in topic sub-wikis.

**Steps:**

1. If HUB doesn't exist yet, create the hub first:
   - `HUB/wikis.json` (empty registry)
   - `HUB/_index.md` (hub index with empty topic wiki table)
   - `HUB/log.md` (global activity log)
   - `HUB/topics/` directory
   - NO `raw/`, `wiki/`, `output/`, `inbox/`, `config.md`, or `.obsidian/` at the hub level.

2. Create the topic wiki directory structure:
   - `inbox/`, `inbox/.processed/`
   - `raw/`, `raw/articles/`, `raw/papers/`, `raw/repos/`, `raw/notes/`, `raw/data/`
   - `wiki/`, `wiki/concepts/`, `wiki/topics/`, `wiki/references/`
   - `output/`
   - For local wikis (`--local`): append `.wiki/` to the project's `.gitignore`.

3. Create `.obsidian/` directory with minimal vault config:
   - `.obsidian/app.json`:
     ```json
     {
       "showFrontmatter": true,
       "alwaysUpdateLinks": true,
       "newLinkFormat": "relative",
       "useMarkdownLinks": false
     }
     ```
   - `.obsidian/appearance.json`:
     ```json
     {
       "accentColor": ""
     }
     ```
   - `.obsidian/graph.json`:
     ```json
     {
       "collapse-filter": false,
       "search": "",
       "showTags": true,
       "showAttachments": false,
       "showOrphans": true,
       "collapse-color-groups": false,
       "collapse-display": false,
       "showArrow": true,
       "textFadeMultiplier": 0,
       "nodeSizeMultiplier": 1,
       "lineSizeMultiplier": 1
     }
     ```

4. Create empty `_index.md` in every directory following the format in `references/wiki-structure.md`. Use today's date. Set all counts to 0.

5. Create `log.md` with initial entry:
   ```
   # Wiki Activity Log

   ## [YYYY-MM-DD] init | Wiki initialized
   ```

6. Ask the user: "What is this wiki about?" Use their answer to create `config.md` with title, description, scope, and today's date.

7. Register in `HUB/wikis.json` and update hub `_index.md` topic wiki table. For local wikis, add to the `local_wikis` array.

8. Report what was created and suggest:
   - `/wiki:research "topic" --sources 10` — auto-research to bootstrap
   - `/wiki:ingest <url|file|text>` — add source material
   - `/wiki:compile` — compile sources into wiki articles
   - `/wiki:query <question>` — ask questions

---

### If $ARGUMENTS is freeform text (not "init", "config", or empty) and a wiki exists

The user typed something that isn't a known keyword. Detect their intent and route to the right subcommand.

**Check these patterns in order — first match wins:**

| Priority | Intent | Signal patterns | Route to |
|----------|--------|----------------|----------|
| 1 | **Ingest** | Contains a URL (`http://`, `https://`), a file path (`/`, `~/`), or words: "add", "save", "ingest", "read this", "grab this" | `Skill: wiki:ingest` with the URL/path/text |
| 2 | **Resume** | "where was I", "pick up where", "continue", "resume", "get back to", "catch me up", "what was I working on" | `Skill: wiki:query` with `--resume` |
| 3 | **Query** | Starts with what/why/how/when/where/who, contains "?", or words: "tell me about", "explain", "what do we know about" | `Skill: wiki:query` with the question |
| 4 | **Research** | "research", "find out about", "look into", "deep dive", "investigate" | `Skill: wiki:research` with the topic |
| 5 | **Thesis** | "prove that", "is it true that", "verify", "test the claim", "test the hypothesis" | `Skill: wiki:thesis` with the claim |
| 6 | **Compile** | "compile", "process sources", "synthesize", "update articles" | `Skill: wiki:compile` |
| 7 | **Lint** | "check health", "fix wiki", "broken", "problems", "cleanup" | `Skill: wiki:lint` |
| 8 | **Output** | "write a summary", "generate a report", "slides", "create a", "write a" | `Skill: wiki:output` with the request |
| 9 | **Assess** | "compare to", "assess", "gap analysis" | `Skill: wiki:assess` |
| 10 | **Plan** | "plan for", "implementation plan", "architecture for" | `Skill: wiki:plan` |
| 11 | **Retract** | "remove source", "retract", "delete source", "pull out" | `Skill: wiki:retract` |

**Confidence routing:**

- **High confidence** — a single strong signal (URL present, question mark, exact keyword match like "compile" or "resume"). Route directly. Tell the user what you detected:
  > Detected: **ingest** (found URL). Routing to `/wiki:ingest`.
  
  Then invoke the Skill tool with the appropriate command and pass the user's text as arguments.

- **Low confidence** — ambiguous input that could match multiple intents, or no clear signal. Present the top 2-3 matching options as a numbered list:
  > Not sure what you're after. Pick one:
  > 
  > 1. **Query** — ask the wiki what it knows
  > 2. **Research** — search the web and add new sources
  > 3. **Ingest** — add specific material you already have
  > 
  > (1/2/3)
  
  Wait for their choice, then invoke the corresponding Skill.

- **No match** — the text doesn't match any pattern. Show wiki status (fall through to status section below) and list available subcommands.

**Key rules:**
- Never guess when ambiguous. A quick menu is faster than undoing the wrong action.
- Strip the signal words when passing args to the target command (e.g., "add https://example.com" → pass just the URL to ingest, not "add https://example.com").
- Include `--wiki` or `--local` flags from the original args when routing.

---

### If $ARGUMENTS is empty (or just "status"/"stats"/"show") and a wiki exists

Show wiki status:

1. If at the hub level (HUB):
   - Read `HUB/_index.md` and `HUB/wikis.json`
   - For each registered topic wiki, read its `_index.md` to get current stats
   - Show a summary table: wiki name, description, source count, article count
   - Show global log (last 5 entries)

2. If targeting a specific topic wiki (`--wiki <name>` or local):
   - Read its `_index.md` for statistics and recent changes
   - Read `config.md` for title and description
   - Count actual files for accuracy
   - Show: title, location, source/article/output counts, inbox pending, last compiled/lint dates, last 5 recent changes

3. List available subcommands

---

### If no wiki exists and no "init" argument

Tell the user:

> No wiki found. Create one with:
> - `/wiki init quantum-computing` — topic wiki at HUB/topics/quantum-computing/
> - `/wiki init ml` — topic wiki at HUB/topics/ml/
> - `/wiki init notes --local` — project-local wiki at .wiki/
>
> Each topic gets its own wiki with isolated indexes and articles. Queries automatically peek across topic wikis for relevant overlap.
>
> To change where the hub lives (e.g., iCloud Drive): `/wiki config hub-path <path>`

---

### If $ARGUMENTS contains "config"

Configure the wiki system.

#### `config hub-path <path>`

Set a custom hub location. Creates `~/.config/llm-wiki/config.json`.

**Steps:**

1. If `<path>` is provided:
   - Expand `~` in the path
   - Check if the path exists as a directory. If not, offer to create it.
   - Write `~/.config/llm-wiki/config.json` (create `~/.config/llm-wiki/` if needed):
     ```json
     { "hub_path": "<path>" }
     ```
   - If a wiki already exists at the OLD hub location (default `~/wiki/` or previous config):
     - Ask: "Move existing wiki data from `<old>` to `<new>`? (y/n)"
     - If yes: move contents (`mv <old>/* <new>/`), update `wikis.json` paths to reflect new base
     - If no: just update the config — user will move data manually
   - Report: "Hub path set to `<path>`. All wiki commands now use this location."

2. If no `<path>` provided (just `config hub-path`):
   - Read `~/.config/llm-wiki/config.json` if it exists
   - Report: "Current hub path: `<path>`" or "Hub path: `~/wiki/` (default — no custom config)"

#### `config` (no subcommand)

Show all configuration:
- **Hub path**: current resolved path (and whether it's from config or default)
- **Config file**: `~/.config/llm-wiki/config.json` (exists / not found)
- **Topic wikis**: count from wikis.json
