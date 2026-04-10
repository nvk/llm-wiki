# Projects

Projects are a way to group related outputs — playbooks, reports, code, images, data — into a single container with a goal, lifecycle, and manifest. They live inside a topic wiki's `output/` directory.

## Why folders, not pure metadata

Outputs are multi-artifact. A single project can produce markdown deliverables plus images referenced by `![](screenshot.png)`, Python prototypes, CSV data exports, and generated diagrams. Relative paths only work when these artifacts colocate. Pure metadata overlays (keeping `output/` flat and tagging via frontmatter) break the moment the first binary asset appears.

Therefore: project folders are the primary home. Metadata overlay handles the two cases folders can't — multi-project membership (rare) and lifecycle state.

## Directory layout

```
<topic-wiki>/
└── output/
    ├── projects/
    │   ├── bitcoin-quantum-risk/
    │   │   ├── _project.md              # manifest — goal, status, narrative, derived members
    │   │   ├── playbook.md              # main deliverable
    │   │   ├── threat-model.png         # assets next to the thing that uses them
    │   │   ├── code/
    │   │   │   └── ecc-crack-demo.py
    │   │   └── data/
    │   │       └── key-exposure-analysis.csv
    │   └── llm-wiki-roadmap/
    │       └── _project.md
    └── playbook-improving-llm-wiki-2026-04-08.md   # loose outputs still allowed
```

## Rules

1. **Multi-file or binary artifacts require a project folder.** Code, images, CSVs, SVGs, PDFs — all colocate with the markdown that references them.
2. **Single loose markdown outputs can stay flat in `output/`** for backward compatibility.
3. **`_project.md` is the manifest.** Lives inside the project folder. Contains goal, status, human-written narrative, and a derived member list.
4. **Multi-project membership via `also_in:` frontmatter.** An output's physical home is one project folder. If it's also relevant to another project, add `also_in: [other-slug]` in frontmatter. The other project's `_project.md` picks it up via derived backlinks.
5. **Lifecycle as metadata.** `status: active | archived | retracted` in `_project.md` frontmatter. Archive does NOT move folders — it just flips a flag. Preserves all links and git history.
6. **Max nesting depth: 3 levels inside a project folder.** `projects/<slug>/code/file.py` is the deepest shape allowed.
7. **Slugs**: lowercase, hyphen-separated, max 40 characters. Semantic, not date-prefixed.
8. **Goal is mandatory** at project creation. Forces clarity per PARA discipline.

## `_project.md` format

```markdown
---
title: "Bitcoin Quantum Risk Analysis"
type: project-manifest
goal: "Ship a migration plan for Bitcoin's quantum transition"
status: active
created: YYYY-MM-DD
updated: YYYY-MM-DD
tags: [bitcoin, quantum, migration]
related_wikis: [quantum-computing, bitcoin-treasury]
---

# Bitcoin Quantum Risk Analysis

## Goal
<!-- HUMAN — what this project is trying to accomplish -->

## Context
<!-- HUMAN — why now, what triggered this, stakeholders -->

## Current State
<!-- HUMAN — where things stand, what's next, outstanding questions -->

## Members
<!-- DERIVED — regenerated on demand, do not hand-edit below -->
- [playbook.md](playbook.md) — main deliverable
- [threat-model.png](threat-model.png) — attack surface diagram
- [code/ecc-crack-demo.py](code/ecc-crack-demo.py)
- [data/key-exposure-analysis.csv](data/key-exposure-analysis.csv)
<!-- /DERIVED -->

## External Members (via also_in)
<!-- DERIVED — outputs living in other project folders that also_in this project -->
<!-- /DERIVED -->

## Research Sessions
<!-- HUMAN — link to research log entries, raw sources, theses -->
```

**Two zones**: human-written prose (Goal, Context, Current State, Research Sessions) and derived sections (Members, External Members). Derived sections are regenerated between delimiter comments; prose is preserved.

## Output frontmatter (for members)

Every markdown output inside a project folder should carry:

```yaml
---
title: "..."
project: <slug>                   # the folder this file lives in
also_in: [<other-slug>]           # optional cross-project membership
---
```

Binary files (`.png`, `.svg`, `.pdf`, `.csv`, `.json`, `.zip`) are exempt from frontmatter requirements. Other text files (`.py`, `.ts`, `.sh`) get a comment header where language allows, or are auto-tracked by folder position only.

## Focus — the session state

The core UX primitive is **focus**, an ambient project context similar to `cd`-ing into a directory. Once focused, every `/wiki` command inherits the project context until the user explicitly unfocuses.

**Location**: `<topic-wiki>/.wiki-session.json` (per topic wiki, gitignored)

**Schema**:
```json
{
  "focused_project": "bitcoin-quantum-risk",
  "focused_at": "2026-04-10T14:30:00Z",
  "last_commands": ["research PQC migration", "add https://..."]
}
```

Short-lived, cheap to lose. If the file is missing or malformed, treat it as "no focus". Clearing it never destroys data.

**Lifecycle**:
- `/wiki:project focus <slug>` — set focus
- `/wiki:project unfocus` — clear focus (removes the file)
- Any `/wiki:*` command that accepts `--project <slug>` explicitly overrides the focused project for that single invocation
- `/wiki:project show` with no arg shows the currently focused project

## Lifecycle states

| Status | Behavior |
|--------|----------|
| `active` | Default. Appears in status, queries, and listings. |
| `archived` | Completed. Excluded from default queries. Still listed via `/wiki:project list --archived`. Folder stays put. |
| `retracted` | Mistake/withdrawn. Excluded from all queries by default. Folder stays put. Reversible. |

Transitions never move files. Always edit `_project.md` frontmatter.

## Multi-project membership

Physical home = one project folder. An output can belong to additional projects via frontmatter:

```yaml
---
title: "ECC Threat Model"
project: bitcoin-quantum-risk      # physical home
also_in: [llm-wiki-roadmap]        # also linked from this project's manifest
---
```

When a project's `_project.md` is regenerated, its External Members section is populated by scanning all outputs (across project folders and loose) for `also_in:` entries containing its slug. The file is not duplicated.

**Do not** use symlinks or hardlinks for multi-membership. They break on iCloud, git, and cross-platform moves.

## Cross-wiki scoping (v1 limitation)

Projects are scoped to a single topic wiki. A project in `meta-llm-wiki` cannot reference outputs in `quantum-computing`. Use `related_wikis:` in the project manifest to declare informal cross-wiki connections without file-level references.

Cross-wiki projects may be added in a future version. v1 keeps the problem small.

## Slug conventions

- Lowercase, hyphen-separated (`bitcoin-quantum-risk`)
- Max 40 characters
- No dates, no uppercase, no special characters
- Must be unique within the topic wiki
- Collision → explicit error with existing path

## What to avoid

- **Physical lifecycle folders** (`active/`, `done/`, `archived/`) — breaks links on status changes
- **Deep nesting beyond 3 levels** — `projects/<slug>/code/file.py` is the max shape
- **Date-prefixed slugs** — date lives in frontmatter
- **Mandatory projects** — loose outputs remain allowed
- **File duplication for multi-membership** — use `also_in:` frontmatter references
- **Cross-wiki project membership in v1** — use `related_wikis:` instead

## Derived index regeneration

The Members and External Members sections of `_project.md` are derived caches (same pattern as `_index.md` files). They are regenerated on demand:

1. Read folder contents (scan `<project-path>/**/*`)
2. Filter by file type (exclude `_project.md` itself)
3. For External Members: grep all markdown files in `output/` for `also_in: [.*<slug>.*]` frontmatter
4. Build the member list with relative paths
5. Replace only the content between `<!-- DERIVED -->` and `<!-- /DERIVED -->` delimiter comments

If delimiter comments are missing, warn and do not regenerate. Never overwrite hand-written prose.
