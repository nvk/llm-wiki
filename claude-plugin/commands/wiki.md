---
description: "LLM wiki knowledge base — understands natural language. Say what you want (add a URL, ask a question, research a topic, resume work) and it routes to the right subcommand. Also handles init, status, and config."
argument-hint: "[<natural language request>] [init <topic-name> [--local]] [config hub-path [<path>]] [--wiki <name>]"
allowed-tools: Read, Write, Edit, Glob, Bash(ls:*), Bash(wc:*), Bash(mkdir:*), Bash(date:*), Bash(mv:*)
---

## Your task

**Resolve the wiki.** Do NOT search the filesystem or read reference files — follow these steps:
1. Read `$HOME/.config/llm-wiki/config.json`. If it has `resolved_path` → HUB = that value, skip to step 3. If only `hub_path`, expand leading `~` only (not tildes in `com~apple~CloudDocs`), set HUB, write `resolved_path` back, skip to step 3.
2. If no config → read `$HOME/wiki/_index.md`. If it exists → HUB = `$HOME/wiki`. If nothing found, ask the user where to create the wiki.
3. **Wiki location** (first match): `--local` → `.wiki/` in CWD; `--wiki <name>` → `HUB/wikis.json` lookup; CWD has `.wiki/` → use it; else → HUB.
4. Read `<wiki>/_index.md` if found. Variant: **wiki-neutral** — `wiki.md` is the router, init, and config command, so "wiki missing" is not always an error; the init subcommand creates the wiki, status shows an empty hub gracefully, and the natural-language router explains how to create one.

You are the llm-wiki knowledge base manager. Read the skill at `skills/wiki-manager/SKILL.md` and structure reference at `skills/wiki-manager/references/wiki-structure.md` for full conventions.

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
| 5 | **Thesis** | "prove that", "is it true that", "verify", "test the claim", "test the hypothesis" | `Skill: wiki:research` with `--mode thesis "<claim>"` |
| 6 | **Compile** | "compile", "process sources", "synthesize", "update articles" | `Skill: wiki:compile` |
| 7 | **Lint** | "check health", "fix wiki", "broken", "problems", "cleanup" | `Skill: wiki:lint` |
| 7b | **Librarian** | "librarian", "quality scan", "scan quality", "quality issues", "article quality", "content review", "review my wiki", "review articles", "librarian report", "quality report", "stale articles" | `Skill: wiki:librarian` |
| 7c | **Refresh** | "check freshness", "still current", "up to date", "outdated", "refresh" | `Skill: wiki:refresh` |
| 8 | **Output** | "write a summary", "generate a report", "slides", "create a", "write a" | `Skill: wiki:output` with the request |
| 9 | **Assess** | "compare to", "assess", "gap analysis" | `Skill: wiki:assess` |
| 10 | **Plan** | "plan for", "implementation plan", "architecture for" | `Skill: wiki:plan` |
| 10b | **Lessons Learned** | "learn this", "learn that", "lesson learned", "lessons learned", "absorb this", "capture what we learned", "what did we learn", "session takeaways", "ll" | `Skill: wiki:ll` with the topic hint |
| 11 | **Retract** | "remove source", "retract", "delete source", "pull out" | `Skill: wiki:retract` |
| 12 | **Project (new)** | "new project", "start a project", "create project" (+ slug and goal) | `Skill: wiki:project` with `new <slug> "goal"` |
| 13 | **Project (list)** | "list projects", "what projects", "show projects", "my projects" | `Skill: wiki:project` with `list` |
| 14 | **Project (show)** | "show project X", "what's in project X", "open project X" | `Skill: wiki:project` with `show <slug>` |
| 15 | **Project (archive)** | "archive project", "I'm done with project", "close project" | `Skill: wiki:project` with `archive <slug>` |

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
- Include `--wiki`, `--local`, and `--project` flags from the original args when routing.
- **No ambient project focus**: `--project <slug>` must be passed explicitly by the user. The focus-session mechanism was removed in the v0.2 projects simplification (see `skills/wiki-manager/references/projects.md` § "Focus"). If the user says "work on project X" without a clear sub-intent, treat it as a request to `show` the project — not as a focus state change.

---

### If $ARGUMENTS is empty (or just "status"/"stats"/"show") and a wiki exists

Show wiki status. Before reading any `_index.md`, stale-check it: count `.md` files in the directory vs rows in the index table. If mismatched, rebuild inline from file frontmatter first (see `references/indexing.md` Derived Index Protocol).

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

The user is new or hasn't initialized a wiki yet. Instead of dumping a command list, walk them through getting started.

**Step 1: Welcome and orient.** Explain what llm-wiki does in one sentence, then ask what they want to research:

> **Welcome to llm-wiki** — a knowledge base that researches topics, ingests sources, and compiles them into articles you can query.
>
> To get started, what topic would you like to research? For example:
> - Quantum computing
> - Nutrition and supplements
> - Kubernetes deployment patterns
>
> Just tell me the topic, and I'll set everything up.

**Step 2: On user response,** derive a slug from their topic (lowercase, hyphens, max 40 chars) and run the full init protocol:
1. Create the hub if it doesn't exist (at the resolved HUB path from config, or ask the user where to create it if no config exists — never assume `~/wiki/`)
2. Create the topic wiki at `HUB/topics/<slug>/` with full directory structure
3. Register in wikis.json and update hub _index.md
4. Create config.md using the user's topic description

**Step 3: After init completes,** suggest the immediate next action based on what's most likely useful:

> **Wiki created at `HUB/topics/<slug>/`**
>
> What would you like to do first?
>
> 1. **Research** — I'll search the web and build your knowledge base automatically
>    → Just say: `/wiki:research "<your topic>" --wiki <slug>`
>
> 2. **Add a specific source** — paste a URL or file path
>    → Just say: `/wiki:ingest <url>`
>
> 3. **Import existing notes** — drop files into `HUB/topics/<slug>/inbox/`
>    → Then run: `/wiki:ingest --inbox`

Do NOT show the full command reference, config options, or advanced flags during onboarding. Keep it to these three options. The user can discover the rest via `/wiki` (status view) once they have a wiki.

**Permission hint (one-time):** If this is the first wiki being created, also append:

> **Tip:** Research sessions fetch many URLs. To skip approval prompts, add this to your project's `.claude/settings.local.json`:
> ```json
> "WebFetch", "WebSearch"
> ```
> in the `permissions.allow` array.

---

### If $ARGUMENTS contains "config"

Configure the wiki system.

#### `config hub-path <path>`

Set a custom hub location. Creates `~/.config/llm-wiki/config.json`.

**Steps:**

1. If `<path>` is provided:
   - Expand `~` in the path to get the absolute path
   - Check if the path exists as a directory. If not, offer to create it.
   - Write `~/.config/llm-wiki/config.json` (create `~/.config/llm-wiki/` if needed) with BOTH the user-facing path and the pre-computed absolute path:
     ```json
     {
       "hub_path": "<path as the user typed it>",
       "resolved_path": "<absolute path with ~ expanded>"
     }
     ```
     The `resolved_path` is consumed by hub resolution so tilde expansion never runs again. See `references/hub-resolution.md`.
   - Suggest creating a symlink for maximum robustness:
     > For fastest hub resolution, also run: `ln -s "<resolved_path>" ~/wiki`
     > This makes `~/wiki/` always resolve immediately, even without reading config.
   - If a wiki already exists at the OLD hub location (previous config path or `~/wiki/` fallback):
     - Ask: "Move existing wiki data from `<old>` to `<new>`? (y/n)"
     - If yes: move contents (`mv <old>/* <new>/`), update `wikis.json` paths to reflect new base
     - If no: just update the config — user will move data manually
   - Report: "Hub path set to `<path>`. All wiki commands now use this location."

2. If no `<path>` provided (just `config hub-path`):
   - Read `~/.config/llm-wiki/config.json` if it exists
   - Report current hub path (use `resolved_path` if present, otherwise `hub_path`)
   - If `resolved_path` is missing from config, compute it now and write it back
   - Report: "Current hub path: `<path>`" or "No hub configured. Run `config hub-path <path>` to set one."

#### `config` (no subcommand)

Show all configuration:
- **Hub path**: current resolved path (and whether it's from config or default)
- **Config file**: `~/.config/llm-wiki/config.json` (exists / not found)
- **Topic wikis**: count from wikis.json
