---
description: "Capture, research, shape, catalog, and explicitly promote Ideas into Projects through natural language."
argument-hint: "new [<slug>] \"<seed>\" | list [filters] | show|develop|shape|promote|archive <slug> [--wiki <name>] [--local]"
allowed-tools: Read, Write, Edit, Glob, Grep, WebFetch, WebSearch, Bash(ls:*), Bash(wc:*), Bash(date:*), Bash(mkdir:*)
---

## Your task

Manage Ideas between compiled Concepts and committed Projects. Read
`skills/wiki-manager/references/ideas.md`; load inventory, research, or Project
references only for the operation that needs them.

Resolve HUB from `${LLM_WIKI_CONFIG_DIR:-$HOME/.config/llm-wiki}/config.json` (`hub_path` first), then
`--local`, `--wiki`, CWD `.wiki/`, or HUB. Read indexes first. Writes require
one active topic and never go at hub root.

Natural language is primary. Infer `new`, `list`, `show`, `develop`, `shape`,
`promote`, or `archive`; resolve phrases such as "the podcast thing" from the
conversation, titles, aliases, and Idea indexes. Derive safe slugs.

### Capture: `new [<slug>] "<seed>"`

Check Idea titles/aliases, relevant Concepts/inventory, and Project slugs for
duplicates. Link related Ideas; never merge automatically.

1. Lazily create `inventory/ideas/` and its `_index.md`.
2. Write `inventory/ideas/<slug>.md` with required inventory fields,
   `kind: idea`, `status: proposed`, default `priority: p2`, `next_action`, and
   related wiki/source links when known.
3. Preserve the exact seed under `## Original Seed`. Add concise sections for
   opportunity, target, evidence, assumptions/counterevidence, alternatives,
   current shape, scope/no-gos, risks, questions, success criteria, intended
   deliverable, and decision notes.
4. Rebuild indexes and log `idea | captured <slug>`.

Do not duplicate the seed as a raw note or create a Project.

### Catalog: `list` and `show`

Read the Idea index first; hub-wide lists read only active topics' Idea indexes.
Filter by status, maturity, priority, topic, tags/aliases, owner, next action,
or Project. Default to a short list.

Derive maturity: captured when the record exists; researching from linked raw
research; shaped from `approved_at` plus an Approved Decision Snapshot; project
from a linked non-empty `WHY.md`; delivered from a linked outcome/deliverable.
Never add a synchronized `stage` field.

### Develop: `develop <slug>`

Read the Idea, linked Concepts, and indexes; research only gaps. Evidence goes
in `raw/`, reusable synthesis in `wiki/`, and the Idea distinguishes evidence,
assumptions, contradictions, and unknowns. Update status/date/next action,
indexes, and log. Research never implies approval or Project creation.

### Shape: `shape <slug>`

Challenge the premise. Write minimal, ideal, and optionally lateral versions;
define target, appetite, scope, no-gos, risks, rabbit holes, success criteria,
and deliverable. Without a user choice, set the next action and stop for a
concise decision. With explicit approval of a named version, add
`approved_at: YYYY-MM-DD` and `## Approved Decision Snapshot` containing the
chosen rationale, scope, no-gos, success criteria, and deliverable. Update
indexes and log (`idea | shaped <slug>`).

### Promote: `promote <slug>`

Require explicit approval in the current request or both `approved_at` and an
Approved Decision Snapshot. Otherwise ask for approval. Promotion is idempotent:

1. Show an already-linked valid Project; do not duplicate it.
2. Refuse active/archived Project slug collisions.
3. Create `output/projects/<slug>/WHY.md` from the approved rationale with a
   backlink, and freeze the snapshot as `BRIEF.md` with a backlink.
4. Add `project: output/projects/<slug>` and `promoted: YYYY-MM-DD` to the Idea,
   update its next action/indexes, and log
   `idea | promoted <slug> -> output/projects/<slug>`.

The Idea remains catalog/lineage. Plans, implementation, artifacts, outcomes,
and changing delivery truth belong to the Project.

### Archive and report

`archive` sets Idea `status: archived`, date, decision notes, indexes, and log;
it never archives a linked Project. If fuzzy wording could mean Idea, Project,
or both, ask before changing state.

Report path, topic, status, maturity, links, Project, and next action.
