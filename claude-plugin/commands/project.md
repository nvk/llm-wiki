---
description: "Manage projects inside a topic wiki. Projects are folders under output/projects/ that group related outputs (playbooks, images, code, data) with a goal captured in WHY.md."
argument-hint: "new <slug> \"goal\" | list [--archived] | show <slug> | add <slug> <path> | archive <slug>"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(mkdir:*), Bash(mv:*), Bash(date:*), Bash(basename:*), Bash(find:*), Bash(wc:*)
---

## Your task

Manage projects — folders inside a topic wiki's `output/projects/` directory that group related outputs. The only required file in a project is `WHY.md`, which captures the goal/rationale in plain markdown.

**Resolve the wiki.** Do NOT search the filesystem or read reference files — follow these steps:
1. Read `$HOME/wiki/_index.md`. If it exists → HUB = `$HOME/wiki`. Skip to step 3.
2. If not → read `$HOME/.config/llm-wiki/config.json`. Use `resolved_path` as HUB. If only `hub_path` exists, expand leading `~` only (not tildes in `com~apple~CloudDocs`), set HUB, write `resolved_path` back. If no config → HUB = `$HOME/wiki`.
3. **Wiki location** (first match): `--local` → `.wiki/` in CWD; `--wiki <name>` → `HUB/wikis.json` lookup; CWD has `.wiki/` → use it; else → HUB.
4. Read `<wiki>/_index.md` if found. Variant: **wiki-neutral** — see deviation below for the step-4 fallback.

Read the projects architecture at `skills/wiki-manager/references/projects.md` for the full rationale — particularly *why* `WHY.md` is the only required file (it holds the precious, non-derivable rationale) and *why* everything else is derived from filesystem state.

### Deviation: wiki resolution step 4

The standard prelude's step 4 (fallback to HUB) becomes: **ask the user which topic wiki, or fail if no topic wikis exist.** Project operations against an empty hub have nothing to operate on. All project paths below are relative to the resolved wiki root (`<wiki-root>/output/projects/<slug>/`).

### Parse $ARGUMENTS

The first word is the subcommand. Subsequent words are args.

| Subcommand | Args | Purpose |
|------------|------|---------|
| `new` | `<slug> "goal"` | Create a new project with a WHY.md |
| `list` | `[--archived]` | List projects (active by default) |
| `show` | `<slug>` | Show a project's WHY.md and member files |
| `add` | `<slug> <path>` | Move an existing file into a project |
| `archive` | `<slug>` | Move folder to `.archive/` (reversible via mv) |

If `$ARGUMENTS` is empty, show help (list subcommands with examples) and exit.

**Removed in v0.2 simplification**: `focus`, `unfocus`, `retract`, `rename`. See `references/projects.md` § "Focus" for the rationale on dropping focus (pass `--project <slug>` explicitly instead). Rename and retract are rare and better done via direct filesystem ops (`mv`, `rm -rf`) than wrapped subcommands.

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

**Check collision**: If `<wiki-root>/output/projects/<slug>/` already exists (active or archived), fail: `Project "<slug>" already exists at <path>. Use a different slug.`

**Create**:
1. `mkdir -p <wiki-root>/output/projects/<slug>/`
2. Write `<wiki-root>/output/projects/<slug>/WHY.md` using the template below
3. Report: `Created project "<slug>" at <path>.`

**`WHY.md` template**:
```markdown
# <Title>

<goal>

## Context

<!-- Why this project exists, what triggered it, who cares. Delete this section if you don't need it. -->

## Current state

<!-- Where things stand, what's next, outstanding questions. Delete this section if you don't need it. -->
```

Derive the title from the slug: `bitcoin-quantum-risk` → `Bitcoin Quantum Risk`. Capitalize each hyphen-separated token. Drop the `<!-- ... -->` placeholders if the user gave a goal rich enough to stand alone.

**No frontmatter.** `WHY.md` is plain markdown. The convention is "first `#` heading = title, body = rationale." That's it. Don't add `type:`, `status:`, `created:`, `updated:` — filesystem state is the state.

---

### Subcommand: `list [--archived]`

List projects in the resolved wiki.

1. Glob `<wiki-root>/output/projects/*/WHY.md` (active projects)
2. If `--archived` is set, also glob `<wiki-root>/output/projects/.archive/*/WHY.md`
3. For each, read the first `#` heading (the title) and the first non-heading paragraph (the goal, first 120 chars)
4. Count members: `ls <wiki-root>/output/projects/<slug>/` minus `WHY.md`, recursively counting files at max 3 levels
5. Render a table:

```
Active projects (N)

| Slug | Title | Goal | Members |
|------|-------|------|---------|
| bitcoin-quantum-risk | Bitcoin Quantum Risk | Ship a migration plan for Bitcoin's quantum transition | 4 |
| llm-wiki-roadmap | llm-wiki Roadmap | v0.1 features | 2 |
```

With `--archived`, render a second "Archived projects" table below.

If no projects exist, report: `No projects in <wiki>. Create one with /wiki:project new <slug> "goal".`

---

### Subcommand: `show <slug>`

Show a project's goal and members.

1. Look for `<wiki-root>/output/projects/<slug>/WHY.md` (or `.archive/<slug>/WHY.md` if not in active)
2. If not found, fail: `Project "<slug>" not found.`
3. Print the full WHY.md
4. Below it, print a member list scanned at display time:
   - Glob the project folder (max 3 levels deep), excluding WHY.md, hidden files, `.DS_Store`
   - Sort: markdown first, then code, then binaries
   - Render as a relative-path list, one per line

No derived cache, no regeneration step — `show` always reflects current filesystem state.

---

### Subcommand: `add <slug> <path>`

Move an existing file into a project.

1. Verify the project exists: `<wiki-root>/output/projects/<slug>/WHY.md`. If not, fail: `Project "<slug>" does not exist. Create it first with /wiki:project new <slug> "goal".`
2. Resolve the source path (absolute or relative to wiki root)
3. Verify the file exists
4. `mv <source> <wiki-root>/output/projects/<slug>/<basename>`
5. Report: `Added <basename> to project "<slug>".`

**Warning**: If the source file is referenced by other articles (grep for its old path in `wiki/` and `output/`), print those references and warn the user they may be broken. Do not auto-fix — the user decides whether to update the links manually or run lint.

**Frontmatter note**: This command does **not** add `project: <slug>` to the moved file's frontmatter. Folder position is authoritative; frontmatter duplication is a drift trap. If the user wants Obsidian-style project tagging for search, they can add it manually — it's not required.

---

### Subcommand: `archive <slug>`

Move a project to `.archive/`.

1. Verify the project exists: `<wiki-root>/output/projects/<slug>/WHY.md`
2. `mkdir -p <wiki-root>/output/projects/.archive/`
3. `mv <wiki-root>/output/projects/<slug> <wiki-root>/output/projects/.archive/<slug>`
4. Report: `Archived "<slug>". Folder moved to output/projects/.archive/<slug>. Reverse with: mv output/projects/.archive/<slug> output/projects/<slug>.`

This is the entire archive operation. No frontmatter updates, no status flags, no linked-file cleanup. Filesystem state is the state.

**Broken links**: Files elsewhere in the wiki that linked to the archived project will now have broken links. Lint check C4 will catch these on the next run. This is an intentional tradeoff — the simpler archive model is worth the broken-link cost because archiving is rare and lint already handles broken links for every other reason.

---

## Report

After any mutation, output:

- **Action taken**: created/listed/shown/added/archived
- **Project(s) affected**: slug and path
- **Members delta** (for `add`): `+1 member` or equivalent
- **Next steps**: suggestions like `/wiki:research <topic> --project <slug>` or `/wiki:project show <slug>`
