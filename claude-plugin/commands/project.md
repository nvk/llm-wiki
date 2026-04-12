---
description: "Manage projects inside a topic wiki. Projects are folders under output/projects/ that bundle related outputs (playbooks, images, code, data) with a goal, lifecycle, and manifest. Focus into a project to scope subsequent commands automatically."
argument-hint: "new <slug> \"goal\" | list [--archived] | show [<slug>] | add <slug> <path> | focus <slug> | unfocus | archive <slug> | retract <slug> | rename <old> <new>"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(mkdir:*), Bash(mv:*), Bash(date:*), Bash(rm:*), Bash(basename:*), Bash(find:*), Bash(wc:*)
---

## Your task

Manage projects — folders inside a topic wiki's `output/projects/` directory that group related outputs with a goal, lifecycle, and manifest.

Follow the standard prelude in `skills/wiki-manager/references/command-prelude.md` (variant: **wiki-neutral** — see deviation below for the step-4 fallback).

Read the projects architecture at `skills/wiki-manager/references/projects.md` for the full specification of folder layout, `_project.md` manifest format, lifecycle states, multi-project membership via `also_in:`, and focus session state.

### Deviation: wiki resolution step 4

The standard prelude's step 4 (fallback to HUB) becomes: **ask the user which topic wiki, or fail if no topic wikis exist.** Project operations against an empty hub have nothing to operate on. All project paths below are relative to the resolved wiki root (`<wiki-root>/output/projects/<slug>/`).

### Parse $ARGUMENTS

The first word is the subcommand. Subsequent words are args.

| Subcommand | Args | Purpose |
|------------|------|---------|
| `new` | `<slug> "goal"` | Create a new project |
| `list` | `[--archived]` | List all projects |
| `show` | `[<slug>]` | Show a project manifest (or focused project if no arg) |
| `add` | `<slug> <path>` | Move an existing file into a project |
| `focus` | `<slug>` | Set ambient project context |
| `unfocus` | (none) | Clear ambient project context |
| `archive` | `<slug>` | Mark status: archived (no file moves) |
| `retract` | `<slug>` | Mark status: retracted (no file moves) |
| `rename` | `<old> <new>` | Rename a project folder + update references |

If `$ARGUMENTS` is empty, show help (list subcommands with examples) and exit.

---

### Subcommand: `new <slug> "goal"`

Create a new project.

**Validate slug**:
- Lowercase only
- Hyphen-separated
- Max 40 characters
- No spaces, no uppercase, no special chars except `-`
- If invalid, suggest a corrected version and exit: `Invalid slug "Foo Bar" — use "foo-bar" instead.`

**Validate goal**: Mandatory. If missing, prompt: `Goal is required. What is this project trying to accomplish?`

**Check collision**: If `<wiki-root>/output/projects/<slug>/` already exists, fail: `Project "<slug>" already exists at <path>. Use a different slug.`

**Create**:
1. `mkdir -p <wiki-root>/output/projects/<slug>/`
2. Write `<wiki-root>/output/projects/<slug>/_project.md` with the template below
3. Auto-focus into the new project (write `.wiki-session.json`)
4. Report: `Created project "<slug>" at <path>. Focused.`

**`_project.md` template**:
```markdown
---
title: "<human title derived from slug>"
type: project-manifest
goal: "<goal>"
status: active
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
tags: []
related_wikis: []
---

# <Title>

## Goal

<goal>

## Context

<!-- Why this project exists, what triggered it, who cares -->

## Current State

<!-- Where things stand, what's next, outstanding questions -->

## Members
<!-- DERIVED — regenerated on demand, do not hand-edit below -->
<!-- /DERIVED -->

## External Members (via also_in)
<!-- DERIVED — outputs in other project folders that also_in this project -->
<!-- /DERIVED -->

## Research Sessions

<!-- Link to research log entries, raw sources, theses -->
```

Derive the title from the slug: `bitcoin-quantum-risk` → `Bitcoin Quantum Risk`. Capitalize each hyphen-separated token.

---

### Subcommand: `list [--archived]`

List all projects in the resolved wiki.

1. Glob `<wiki-root>/output/projects/*/_project.md`
2. For each manifest, read frontmatter: `title`, `goal`, `status`, `created`, `updated`
3. Count members: `ls <wiki-root>/output/projects/<slug>/` minus `_project.md`
4. Filter: by default show only `status: active`. If `--archived`, also show `archived`. Never show `retracted` unless `--all` is also passed.
5. Sort by `updated` descending
6. Render a table:

```
Active Projects (N)

| Slug | Title | Goal | Members | Updated |
|------|-------|------|---------|---------|
| bitcoin-quantum-risk | Bitcoin Quantum Risk | Ship migration plan | 4 | 2026-04-10 |
| llm-wiki-roadmap | llm-wiki Roadmap | v0.1 features | 2 | 2026-04-09 |
```

If currently focused, mark the focused project with `* `:
```
* bitcoin-quantum-risk | Bitcoin Quantum Risk | ...
```

---

### Subcommand: `show [<slug>]`

Show a project's manifest.

- If `<slug>` not provided, use the focused project from `.wiki-session.json`. If nothing is focused, fail: `No project focused. Usage: /wiki:project show <slug> or /wiki:project focus <slug> first.`
- Read `<wiki-root>/output/projects/<slug>/_project.md`
- Regenerate the derived Members and External Members sections inline (see "Regenerate derived sections" below)
- Print the full manifest to the user

---

### Subcommand: `add <slug> <path>`

Move an existing file into a project.

1. Verify the project exists: `<wiki-root>/output/projects/<slug>/_project.md`. If not, fail: `Project "<slug>" does not exist. Create it first with /wiki:project new <slug> "goal".`
2. Resolve the source path (absolute or relative to wiki root)
3. Verify the file exists
4. Move it: `mv <source> <wiki-root>/output/projects/<slug>/<basename>`
5. If the file is markdown, update its frontmatter to add `project: <slug>` (preserving existing frontmatter, adding the field if absent)
6. Regenerate the project's `_project.md` derived Members section
7. Report: `Added <basename> to project "<slug>".`

**Warning**: If the source file is referenced by other articles (grep for its old path), print those references and warn the user they may be broken. Do not auto-fix.

---

### Subcommand: `focus <slug>`

Set the ambient project context.

1. Verify project exists: `<wiki-root>/output/projects/<slug>/_project.md`. If not, fail.
2. Write `<wiki-root>/.wiki-session.json`:
   ```json
   {
     "focused_project": "<slug>",
     "focused_at": "<ISO 8601 now>",
     "last_commands": []
   }
   ```
3. Report: `Focused on "<slug>". Subsequent /wiki commands will inherit this project context. Run /wiki:project unfocus to clear.`

---

### Subcommand: `unfocus`

Clear the ambient project context.

1. Delete `<wiki-root>/.wiki-session.json` if it exists
2. Report: `Unfocused. Commands no longer scoped to a project.`

Safe to call even if no focus is set.

---

### Subcommand: `archive <slug>`

Mark a project as archived without moving any files.

1. Read `<wiki-root>/output/projects/<slug>/_project.md`
2. Update frontmatter: `status: archived`, `updated: <today>`
3. If the focused project is `<slug>`, unfocus
4. Report: `Archived "<slug>". Folder preserved. Excluded from default queries.`

---

### Subcommand: `retract <slug>`

Mark a project as retracted (mistake/withdrawn) without moving any files.

1. Read `_project.md`
2. Update frontmatter: `status: retracted`, `updated: <today>`
3. Unfocus if needed
4. Report: `Retracted "<slug>". Folder preserved. Excluded from default queries. Reversible by editing _project.md status.`

---

### Subcommand: `rename <old> <new>`

Rename a project folder and update references.

1. Validate `<new>` slug (same rules as `new`)
2. Check collision: fail if `<new>` already exists
3. `mv <wiki-root>/output/projects/<old> <wiki-root>/output/projects/<new>`
4. Update the manifest's title (derive from new slug)
5. Grep all files inside the new folder for `project: <old>` and replace with `project: <new>`
6. Grep all markdown files in the topic wiki for `also_in: [.*<old>.*]` and update to `<new>`
7. If focused on `<old>`, update focus to `<new>`
8. Report: `Renamed project "<old>" → "<new>". N files updated.`

**Warning**: If there are incoming references from other topic wikis (cross-wiki links), print them and warn they may break. Do not auto-fix v1.

---

## Regenerate derived sections

This helper logic runs from `new`, `add`, `show`, and `rename`.

**Members section**:
1. Scan `<wiki-root>/output/projects/<slug>/` recursively (max 3 levels)
2. Exclude `_project.md` itself, hidden files, and `.DS_Store`
3. For each file, build a relative path (`playbook.md`, `code/demo.py`, etc.)
4. Sort: markdown first, then code, then images/data
5. Render as markdown list with relative links:
   ```
   - [playbook.md](playbook.md) — <title from frontmatter or filename>
   - [threat-model.png](threat-model.png)
   - [code/demo.py](code/demo.py)
   ```

**External Members section**:
1. Glob `<wiki-root>/output/projects/*/*.md` (not the current project)
2. Glob `<wiki-root>/output/*.md` (loose outputs)
3. For each file, read frontmatter
4. If `also_in` contains `<slug>`, add to External Members with its relative path from the current project's folder

**Replacement**:
1. Read the existing `_project.md`
2. Find the delimiter comments: `<!-- DERIVED -->` ... `<!-- /DERIVED -->`
3. Replace the content between them with the freshly generated list
4. If delimiters are missing, print a warning: `Manifest <path> is missing <!-- DERIVED --> delimiters. Skipping regeneration to protect hand-written content.` Do not modify the file.
5. Update the `updated:` frontmatter field to today

---

## Focus-aware behavior for other commands

Other `/wiki:*` commands should respect the focused project when no explicit `--project` flag is passed:

1. At the start, read `<wiki-root>/.wiki-session.json` if it exists
2. If `focused_project` is set, treat it as an implicit `--project <slug>`
3. Explicit `--project <slug>` always wins over focus

This file is the source of truth for focus. This command is the only one that writes it.

---

## Report

After any mutation, output:

- **Action taken**: created/listed/shown/added/focused/unfocused/archived/retracted/renamed
- **Project(s) affected**: slug and path
- **Members delta**: if applicable, `+1 member` or `regenerated with N members`
- **Focus state**: current focused project or "none"
- **Next steps**: suggestions like `/wiki:research <topic>` or `/wiki:project show`
