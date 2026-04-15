# Projects

Projects group related outputs — markdown deliverables, images, code, data — into a single folder with a goal. They live inside a topic wiki's `output/projects/` directory.

## Why projects exist at all

Outputs are often multi-artifact. A single deliverable can produce a markdown playbook plus images referenced by `![](screenshot.png)`, a Python prototype, a CSV export, and a generated diagram. **Relative paths only work when these artifacts colocate.** A pure metadata overlay that keeps `output/` flat and tags via frontmatter breaks the moment the first binary asset appears — markdown image links no longer resolve, scripts can't find their data files, and the user has to manually prefix every asset reference.

Project folders solve this by making colocation the primary structure. The folder *is* the project. Everything else (goal, status, members) is derivable from the folder and what's in it.

## Why `WHY.md` is the only required file

Earlier iterations of this architecture (v0.1.0, v0.1.1) used a `_project.md` manifest with YAML frontmatter (`type: project-manifest`, `goal`, `status`, `created`, `updated`), human-written narrative sections, and a derived Members list between `<!-- DERIVED -->` delimiters. That manifest held exactly one thing that couldn't be derived from elsewhere: **the goal — the "why this project exists"**. Everything else (status, timestamps, member list) was either filesystem state or derivable by scanning the folder.

`WHY.md` preserves the precious part (the goal / rationale / "why") and drops the machinery around it. It is plain markdown, no frontmatter, no schema. The convention is:

- First `#` heading → the project title
- Body → goal, rationale, context, current state, notes — whatever the human wants to write

LLMs rebuild wrong without rationale. LLMs don't need a manifest format to read a markdown file. Keep the first, drop the second.

## Directory layout

```
<topic-wiki>/
└── output/
    ├── _index.md
    ├── projects/
    │   ├── bitcoin-quantum-risk/
    │   │   ├── WHY.md                  # goal + rationale (the only required file)
    │   │   ├── playbook.md             # main deliverable
    │   │   ├── threat-model.png        # assets colocated with the markdown that uses them
    │   │   ├── code/
    │   │   │   └── ecc-crack-demo.py
    │   │   └── data/
    │   │       └── key-exposure-analysis.csv
    │   ├── llm-wiki-roadmap/
    │   │   └── WHY.md
    │   └── .archive/                   # archived projects live here
    │       └── old-thing/
    │           └── WHY.md
    └── playbook-improving-llm-wiki-2026-04-08.md   # loose outputs still allowed
```

## Rules

1. **Folder is the project.** The directory name is the slug. No manifest file beyond `WHY.md`.
2. **`WHY.md` is required and non-empty.** Plain markdown. First `#` heading is the title. Body is the rationale.
3. **Multi-file or binary artifacts require a project folder.** Code, images, CSVs, SVGs, PDFs colocate with the markdown that references them. This is the whole reason projects exist.
4. **Single loose markdown outputs can stay flat in `output/`** for backward compatibility.
5. **No frontmatter schema on member files.** `project: <slug>` in frontmatter is optional sugar for Obsidian tag-based search; folder position is authoritative. If the two disagree, folder wins.
6. **Max nesting depth: 3 levels inside a project folder.** `projects/<slug>/code/file.py` is the deepest shape allowed.
7. **Slugs**: lowercase, hyphen-separated, max 40 characters. Semantic, not date-prefixed. Unique within the topic wiki.
8. **Goal is mandatory at creation.** Enforced by `/wiki:project new <slug> "goal"` — the goal becomes the body of `WHY.md`.

## Archive = move the folder

Archiving a project is a filesystem operation, not a metadata flip:

```
mv output/projects/<slug> output/projects/.archive/<slug>
```

The folder is preserved, all files stay put, git history continues. `/wiki:project list` shows active projects only by default; `list --archived` includes `.archive/`.

Reason: a `status: archived` frontmatter field in the old model required the manifest to exist, which required the manifest format, which required the derived-members machinery. Moving the folder is one operation and needs zero schema. The tradeoff is that links to archived projects from other files break — but broken links are something lint already catches (C4), so the existing tooling handles it.

There is no separate `retract` lifecycle state. Retraction means deleting the folder. That's a manual operation (`rm -rf`), deliberately not wrapped in a subcommand, because it's destructive and rare.

## Staleness detection

A project is **stale** when new information relevant to it has been ingested since its artifacts were last updated. This is detected by lint check C8b, not by a manifest field, and the chain runs through frontmatter that already exists:

1. Scan the project folder for member files with `sources:` in frontmatter
2. Follow each `sources:` entry to the raw source file
3. Compare the raw source's `ingested:` date to the member's `updated:` date
4. If any source is newer than the member that cites it → the project is stale

No `updated:` field on a manifest. No derived cache. Pure function over the frontmatter that already exists on every output and every raw source. Guaranteed to be accurate because it reads from the authoritative state.

## Focus / ambient project context

**Removed in the v0.2 simplification.** Earlier iterations used a `.wiki-session.json` file with a `focused_project` field, so that `/wiki:ingest`, `/wiki:research`, `/wiki:query`, etc., would implicitly scope to the focused project. This worked but added a mutable state file, focus-aware logic in every consumer command, and two subcommands (`focus`, `unfocus`) whose only job was to manage it.

The simpler model: pass `--project <slug>` explicitly when you want project scope. One extra flag per command vs. a whole session-state mechanism. If a user finds themselves typing `--project foo` on every command, that's a signal they're deep in the project and should probably `cd` into the folder directly.

## What to avoid

- **Physical lifecycle folders** (`active/`, `done/`) — breaks links on status changes. Archive via `.archive/` is the one exception because it's rare.
- **Deep nesting beyond 3 levels** — `projects/<slug>/code/file.py` is the max shape.
- **Date-prefixed slugs** — dates live in filenames inside the folder, not in the slug.
- **Mandatory projects** — loose single-markdown outputs remain allowed in `output/`.
- **File duplication for multi-membership** — use markdown links to cross-reference between projects.
- **Frontmatter-driven lifecycle** — filesystem state is simpler and can't drift.

## Migration from legacy `_project.md`

Existing wikis created under v0.1.0/v0.1.1 will have `_project.md` manifests. Lint check C8c detects these and auto-migrates:

1. Read `_project.md` frontmatter
2. Extract `goal:` (or `title:` if goal is missing)
3. Read the `## Goal`, `## Context`, `## Current State` sections if present
4. Write `WHY.md` in the same folder with the first `#` heading as the title and the extracted prose as the body
5. Delete `_project.md`
6. Report the migration in the lint output

This is the first real application of the lint-is-the-migration principle codified in `linting.md`. One-time healing; idempotent; no separate migration command needed. See `linting.md` C8c for the full rule.
