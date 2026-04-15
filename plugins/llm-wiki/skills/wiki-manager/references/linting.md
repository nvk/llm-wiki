# Linting Rules

## Development Note — Lint is the Migration

**When you change the canonical structure or frontmatter schema, update the rules in this file and in `compilation.md` — do NOT write migration code.**

The wiki treats "file in the wrong place from an old version" and "file in the wrong place from user error" as the same defect. `/wiki:lint --fix` heals both, idempotently. Indexes are already derived caches (see `indexing.md` Derived Index Protocol) — this principle extends to file placement and frontmatter shape.

There are two layers where this principle applies, each with its own rules:

- **Mechanical layer (C11/C12/C13)** — raw-source and wiki-article placement and frontmatter schema. Fully auto-fixable because the canonical location and field shape are pure functions of frontmatter. No judgment required.
- **Editorial layer (C8/C9)** — project grouping inside `output/projects/`. **Never auto-fixed** because "these files belong together" requires human sense-making. C9 surfaces candidates and emits ready-to-paste `/wiki:project new` + `/wiki:project add` blocks for the user to run.

Concretely, when evolving the schema:

- **Renamed a `raw/` or `wiki/` directory?** Update the placement map in C11 and the allowlist in C12. Every existing wiki self-heals on the next lint.
- **Renamed a frontmatter field?** Append an entry to C13's alias table (old → new). Never remove old aliases.
- **Changed an enum value?** Add a value alias in C13. Never remove old values.
- **Added a required field?** Add it to C2 and give it an inference rule (derive from body/filename) or a sane default.
- **New directory under `raw/` or `wiki/`?** Add it to C12's allowlist and C11's placement map.
- **New project-level structure or manifest rule?** Update C8 (and projects.md). Candidate heuristics go in C9.

There is no `/wiki:migrate` command and there should never be one. Lint rules **are** the schema.

**When editing the canonical spec** (`wiki-structure.md`, `compilation.md`, `ingestion.md`, `projects.md`, or any reference that defines paths or frontmatter fields), also:

1. Update the relevant check(s) in this file — mechanical changes touch C11/C12/C13; project-model changes touch C8/C9.
2. Verify `commands/lint.md` still runs the placement/alias pass in the correct order.
3. Verify `commands/compile.md` still runs the placement pre-check on `raw/` as step 0.

## Severity Levels

- **Critical**: Broken functionality — missing indexes, broken links, corrupted frontmatter
- **Warning**: Inconsistency — mismatched counts, stale dates, non-bidirectional links
- **Suggestion**: Improvement opportunity — new connections, missing tags, content gaps

## Check Catalog

### C1: Structure (Critical)

- [ ] Master `_index.md` exists
- [ ] `config.md` exists
- [ ] Every subdirectory under `raw/` and `wiki/` has `_index.md`
- [ ] `output/` has `_index.md`
- [ ] Every `.md` file (excluding `_index.md` and `config.md`) has valid YAML frontmatter delimited by `---`

### C2: Frontmatter (Critical/Warning)

- [ ] Every raw source has: title, source, type, ingested, tags, summary
- [ ] Every wiki article has: title, category, sources, created, updated, tags, summary
- [ ] No empty title or summary fields
- [ ] `category` is one of: concept, topic, reference
- [ ] `type` is one of: articles, papers, repos, notes, data
- [ ] `tags` is a list, not empty

### C3: Index Consistency (Warning)

- [ ] Every .md file in a directory appears in that directory's `_index.md` Contents table
- [ ] No `_index.md` references a non-existent file (dead entries)
- [ ] Statistics in master `_index.md` match actual file counts
- [ ] "Last compiled" and "Last lint" dates are present and valid

### C4: Link Integrity (Warning)

- [ ] All markdown links `[text](path)` in wiki articles resolve to existing files
- [ ] All "See Also" links are bidirectional (if A→B, then B→A)
- [ ] All "Sources" links in wiki articles point to existing raw files

### C4b: Source Provenance (Warning)

- [ ] All `sources:` entries in wiki article frontmatter point to existing raw files (no dangling references to deleted/retracted sources)
- [ ] No `<!--RETRACTED-SOURCE-->` markers remain in article body (these should be resolved via `--recompile` or manual review)
- [ ] No raw source file is referenced by zero wiki articles (orphan source — suggest compilation or removal)

### C5: Tag Hygiene (Warning)

- [ ] No near-duplicate tags (e.g., `ml` and `machine-learning`, `nlp` and `natural-language-processing`)
- [ ] Tags in article frontmatter match tags listed in `_index.md` entries
- [ ] Suggest canonical tag when duplicates found

### C6: Coverage (Suggestion)

- [ ] Every raw source is referenced by at least one wiki article's `sources` field
- [ ] No wiki article has an empty `sources` field
- [ ] Articles with overlapping tags that don't link to each other via "See Also" — suggest connection
- [ ] Orphan articles: no incoming "See Also" links from other articles

### C7: Deep Checks (Suggestion, --deep only)

- [ ] Use WebSearch to verify key factual claims in wiki articles
- [ ] Identify articles that could be enhanced with newer information
- [ ] Suggest new articles that would connect existing ones
- [ ] Check for stale sources (ingested > 6 months ago with no recent compilation)

### C8: Project Hygiene (Critical/Warning/Suggestion)

Validates projects under `output/projects/`. The architecture was simplified in v0.2: a project is a folder with a `WHY.md` that holds the goal/rationale in plain markdown. No manifest format, no DERIVED sections, no status field. See `references/projects.md` for the full rationale.

**Execution order**: run C8c (migration) first so migrated projects pass C8a in the same lint pass. The labels below are in execution order, not alphabetical.

- [ ] **C8c** Legacy `_project.md` migration (**Critical** — auto-fixable). See migration rule below. Runs first so any legacy manifests are healed into `WHY.md` before the presence check looks for them.
- [ ] **C8a** Every `output/projects/<slug>/` directory has a `WHY.md` with non-empty content (**Critical** — projects without rationale become black boxes; LLMs rebuild wrong without the why). The file has no frontmatter requirement. Any `#` heading + body counts as non-empty.
- [ ] **C8d** Slug conforms to spec: lowercase, hyphen-separated, ≤40 chars, no dates (**Warning**).
- [ ] **C8b** Staleness check — for every project, compute transitive source freshness (**Suggestion**). For each member file with `sources:` frontmatter, follow the chain to raw sources. If any raw source's `ingested:` date is newer than the member's `updated:` date, the project may be stale. Report as: `Project <slug> may be stale: N source(s) newer than member artifacts.` Never auto-fixed — staleness triggers human re-evaluation, not automatic regeneration.

**C8c migration rule** (legacy `_project.md` → `WHY.md`):

Pre-v0.2 wikis have `_project.md` manifests with YAML frontmatter and derived Members sections. When lint encounters one:

1. Read `_project.md` frontmatter — extract `goal` and `title` (fall back to slug-derived title if `title:` is absent).
2. Read the body and split into sections by `## ` headings.
3. Identify **derived sections** to drop: any section whose body is (a) entirely between `<!-- DERIVED -->` and `<!-- /DERIVED -->` delimiter comments, or (b) matches the header text `## Members` or `## External Members` even if delimiters are missing. These are regeneratable and not precious.
4. Identify **human sections** to preserve: everything else. This includes `## Goal`, `## Context`, `## Current State`, `## Research Sessions`, and any custom sections the user added (decision logs, open questions, retrospectives, etc.). **The default is preserve — when in doubt, keep it.** LLMs rebuild wrong without rationale, and custom sections are almost always rationale.
5. Determine how to surface the goal. Two cases:
   - **If the body has a `## Goal` section**: preserve it as-is. Do NOT also prepend the frontmatter `goal:` text — that would duplicate. The body version usually has more detail and the same or better phrasing.
   - **If the body has no `## Goal` section**: prepend the frontmatter `goal:` text as the first body paragraph of `WHY.md`, so the rationale is visible without reading the whole file.
6. Write `WHY.md` in the same folder, structured as:
   ```markdown
   # <title>

   <frontmatter goal as first paragraph — ONLY if the body had no ## Goal section; otherwise omit this paragraph>

   <every preserved human section from step 4, in original order, with original `## ` headings>
   ```
7. Delete `_project.md`.
8. Report: `Migrated <slug>/_project.md → <slug>/WHY.md (preserved N sections: <list>).`

**Lossless guarantee**: every human-written section that existed in `_project.md` appears verbatim in `WHY.md`. The only things dropped are frontmatter metadata (dates live in git log, status in filesystem state, tags are optional, type is structural) and derived Members/External Members lists (recomputable by scanning the folder — never precious).

This is the first real application of the lint-is-the-migration principle codified in this file's dev note. Idempotent — re-running has no effect once WHY.md exists. No separate migration command, no version detection. Just lint.

### C9: Project Candidates (Suggestion)

Surfaces loose `output/` content that should be grouped into projects. **Never auto-fixed** — grouping decisions require human judgment.

- [ ] **C9a** Binary assets (`.png`, `.jpg`, `.pdf`, `.csv`, `.svg`, `.zip`) loose directly in `output/` root (not inside `projects/`) — these cannot stay loose per the projects architecture because relative asset paths break. Propose the likely owning project based on filename prefix. (**Critical** — architecture violation)
- [ ] **C9b** Any subdirectory inside `output/` that is NOT `projects/` (or `.archive/` inside `projects/`) and contains files — architecture violation, all subdirectories should be under `output/projects/`. (**Critical**)
- [ ] **C9c** Any `output/projects/<slug>/` folder without a `WHY.md` — this is a malformed project. Suggest: `echo "# <Title>\n\nTODO: goal" > WHY.md` or run `/wiki:project new <slug> "goal"` after archiving the existing folder. (**Warning**)
- [ ] **C9d** ≥3 loose markdown outputs in `output/` that share a common slug prefix (after stripping dates, version tags, and type prefixes) — suggest grouping into a project. (**Suggestion**)

**Candidate report format** (for C9d):

```
### Project Candidates (N)

Suggested: bitcoin-quantum-fud (proposed slug)
  Reason: 5 files share prefix "article-bitcoin-quantum-fud-"
  Files:
    - article-bitcoin-quantum-fud-2026-04-05.md
    - article-bitcoin-quantum-fud-v2-2026-04-06.md
    ...
  Create with:
    /wiki:project new bitcoin-quantum-fud "TODO: fill in goal"
    /wiki:project add bitcoin-quantum-fud article-bitcoin-quantum-fud-2026-04-05.md
    ...
```

**Slug derivation heuristic** (C9d): longest common prefix of ≥3 files, stripped of trailing hyphens, dates (`YYYY-MM-DD`), version tags (`-v\d+`, `-final`, `-release`), and the `article-` / `output-` / `report-` prefixes. If the result is <4 chars or ambiguous, report without a proposed slug and let the user name it.

### C11: Canonical Placement (Critical)

A `raw/` or `wiki/` file's correct path is a pure function of its frontmatter. Misplacement is a structural defect regardless of whether the cause was user error or an old wiki layout. This is the mechanical counterpart to C8/C9, which handle project-level organization. C11 does not touch `output/projects/` — that's C8's territory.

**Placement map** (derive expected path from frontmatter). Resolve in order — the first matching rule wins:

| Order | File kind | Frontmatter key | Value → directory |
|-------|-----------|----------------|-------------------|
| 1 | Thesis file (wiki-side) | `type: thesis` | `wiki/theses/` |
| 2 | Raw source | `type` | `articles` → `raw/articles/`, `papers` → `raw/papers/`, `repos` → `raw/repos/`, `notes` → `raw/notes/`, `data` → `raw/data/` |
| 3 | Wiki article | `category` | `concept` → `wiki/concepts/`, `topic` → `wiki/topics/`, `reference` → `wiki/references/` |

**Disambiguating raw `type: articles/papers/...` from wiki thesis `type: thesis`**: Rule 1 matches only when the value is literally `thesis`. Raw sources never use `thesis` as a type. A file whose frontmatter has both `category` and `type` is a wiki article — use `category` (rule 3). A file with only `type: thesis` is a thesis file (rule 1). A file with only `type` in {articles, papers, repos, notes, data} is a raw source (rule 2).

**Checks**:

- [ ] For every `.md` file under `raw/` and `wiki/` (excluding `_index.md` and `config.md`), compute the expected directory from frontmatter and compare to the actual directory.
- [ ] Raw sources at the hub level (not inside a topic wiki) → misplaced. Hub must only contain `wikis.json`, `_index.md`, `log.md`, and `topics/`.
- [ ] Content directories (`raw/`, `wiki/`, `output/`, `inbox/`) at the hub level → misplaced. Move contents into a topic wiki or quarantine.
- [ ] Files with missing or unreadable frontmatter → defer to C2 (frontmatter fix) before placement can be determined.
- [ ] Out of scope: anything under `output/projects/`. Project-level placement is C8/C9.

**Auto-fix**: `mv` the file to its canonical path (create the destination directory if missing). If the destination already contains a file with the same slug, skip and warn (potential duplicate — user must resolve). After any move, the containing indexes on both sides are invalidated and will rebuild on next read per the Derived Index Protocol.

### C12: Unknown File Quarantine (Warning)

Any file that is not in the canonical allowlist for its location is either a user mistake, a stale artifact from an older wiki version, or a legitimate new kind of thing that the schema hasn't caught up to. Lint surfaces it either way. Like C11, this is scoped to `raw/`, `wiki/`, and the wiki root — not `output/projects/` (C8 handles that).

**Allowlists** (per location):

| Location | Allowed items |
|----------|--------------|
| HUB | `wikis.json`, `_index.md`, `log.md`, `topics/` |
| Topic wiki root | `_index.md`, `config.md`, `log.md`, `raw/`, `wiki/`, `output/`, `inbox/`, `.obsidian/`, `.research-session.json`, `.thesis-session.json` |
| `raw/` | `_index.md`, `articles/`, `papers/`, `repos/`, `notes/`, `data/` |
| `wiki/` | `_index.md`, `concepts/`, `topics/`, `references/`, `theses/` |
| `raw/<type>/` | `_index.md` + `*.md` files with valid frontmatter |
| `wiki/<category>/` | `_index.md` + `*.md` files with valid frontmatter |
| `inbox/` | `.processed/`, `.unknown/`, user-dropped files |

**Checks**:

- [ ] Walk `raw/`, `wiki/`, and the wiki root. For each entry, check against the allowlist for that location.
- [ ] Flag unknown files and directories.
- [ ] Skip `output/` — C8 and C9 own that subtree.

**Auto-fix**:

- Unknown `.md` file with valid frontmatter → route via C11 (canonical placement).
- Unknown `.md` file without frontmatter → move to `inbox/.unknown/` for user triage.
- Unknown directory → **do not auto-delete**. Warn only. Directories may hold user data.
- Unknown non-`.md` file at an unexpected location → move to `inbox/.unknown/`.

### C13: Frontmatter Aliases (Warning)

Legacy field names and enum values are rewritten to their canonical form. This is the one place where schema evolution is encoded — add aliases here instead of writing migrations. Run this check **before** C2 and C11 so downstream checks see canonical field names.

**Why this check exists at all (even while empty):** we want the *framework* for schema evolution in place before we need it, so the first rename ever made to a frontmatter field is a one-line addition to a table rather than "let's design a migration system." The dev note at the top of this file explains the full lint-as-migration principle. C13 itself is the mechanism.

**Key aliases** (old → canonical, append-only — never remove an entry). Populate this table when a real field rename happens; do not pre-populate with speculative entries.

```
# (empty — add entries as schema evolves)
# Format:  old_key  →  canonical_key
# Example: source_url  →  source        # added when raw sources dropped source_url in v0.X.Y
```

**Value aliases** (enum drift — append-only). Populate when an enum value is renamed.

```
# (empty — add entries as enums evolve)
# Format:  old_value  →  canonical_value  (for field: <field_name>)
# Example: article  →  articles  (for field: type)  # added when type enum went plural
```

Note: thesis files use `type: thesis`, not `category`. Do not alias `theses` to a `category` value if anyone ever proposes it — theses are their own file kind under C11 rule 1.

**Checks**:

- [ ] For every `.md` file's frontmatter, scan keys against the key-alias table. If a match is found, rewrite the key to canonical (preserve value).
- [ ] For fields with known enums (`type`, `category`, `confidence`), scan values against the value-alias table. If a match is found, rewrite the value to canonical.
- [ ] Unknown keys not in the alias table and not in the canonical schema → warn (potential new alias needed or typo).

**Auto-fix**: Rewrite the YAML key or value in place using Edit. Preserve field order and comments.

**When the tables are empty** (current state), C13 only runs the unknown-key warning — alias rewriting is a no-op. This is the honest default: we have no backward-compat debt yet, so advertising alias entries would be fiction. First real rename → first real alias entry.

## Auto-Fix Rules (when --fix is set)

| Issue | Auto-Fix Action |
|-------|----------------|
| Missing `_index.md` | Generate from directory contents (read frontmatter of each file) |
| File not in index | Add row using file's frontmatter data |
| Dead index entry | Remove the row |
| Statistics mismatch | Recalculate from actual file counts |
| Missing bidirectional link | Add "See Also" entry to the article missing the backlink |
| Empty frontmatter field | Infer: title from `# heading`, summary from first paragraph |
| Near-duplicate tags | Replace all instances with the canonical form |
| Dangling source reference | Remove the entry from `sources:` frontmatter |
| Unresolved retraction marker | Warn: "Retracted claim not yet reviewed — run `/wiki:retract --recompile` or edit manually" |
| **C8a** `output/projects/<slug>/` missing `WHY.md` | **Warn only** — a project without rationale is a malformed project. Report and prompt the user to create one. Auto-creation would manufacture a fake goal, which is worse than the missing file. |
| **C8b** Staleness detected | **Never auto-fix** — staleness is a signal for human re-evaluation, not automatic content regeneration. |
| **C8c** Legacy `_project.md` found | Migrate to `WHY.md`: extract goal + title + preserved sections from manifest frontmatter and body, write `WHY.md`, delete `_project.md`. See C8 migration rule for the full procedure. |
| Stale `output/_index.md` when `projects/` exists | Regenerate as a projects-aware listing: scan `output/projects/*/WHY.md` for first-heading titles + first-paragraph goals, list them as a table, then list any remaining loose outputs in `output/` below. |
| **C9a/C9b** architecture violations | **Warn** — surface the problem, suggest the fix, never auto-move. User decides. |
| **C9c** Project folder without `WHY.md` | **Warn only** — same as C8a but surfaced in the candidates section. Suggest running `/wiki:project new <slug> "goal"` with the existing slug. |
| **C9d** Loose markdown cluster | **Never auto-fix** — grouping is human-authored via `/wiki:project new` + `/wiki:project add`. |
| **C11** Misplaced file in `raw/` or `wiki/` | `mv` to canonical path derived from frontmatter; create destination dir if missing; invalidate containing indexes. Skip and warn on slug collision |
| **C11** Content dir at hub level | Move contents into appropriate topic wiki or quarantine to `inbox/.unknown/`. Never delete user data |
| **C12** Unknown file in known location | Route through C11 if it has frontmatter, else move to `inbox/.unknown/` |
| **C12** Unknown directory | **Warn only** — never auto-delete |
| **C13** Legacy frontmatter key | Rewrite key to canonical per alias table |
| **C13** Legacy enum value | Rewrite value to canonical per alias table |

## Report Format

```markdown
## Wiki Lint Report — YYYY-MM-DD

### Summary
- Checks run: N
- Issues found: N (N critical, N warnings, N suggestions)
- Auto-fixed: N (if --fix was used)

### Critical Issues
1. [description] — [file path]

### Warnings
1. [description] — [file path]

### Suggestions
1. [suggestion] — [reasoning]

### Coverage
- Sources with no wiki articles: [list]
- Wiki articles with broken links: [list]
- Missing bidirectional links: [list]
- Potential new connections: [list]

### Projects
- Active: N | Archived: N (in `.archive/`)
- Missing `WHY.md` (C8a): [list of slugs]
- Stale (C8b): [list of slugs with source-count diff]
- Legacy `_project.md` migrated (C8c): [list of slugs]

### Project Candidates
- [grouped suggestions per C9, formatted as the candidate report block above]

### Placement & Schema (C11/C12/C13)
- Files moved (C11): [count, list of moves as `old → new`]
- Files quarantined (C12): [count, list of moves to `inbox/.unknown/`]
- Frontmatter keys rewritten (C13): [count by alias]
- Enum values rewritten (C13): [count by alias]
- Unknown directories (C12, warn-only): [list]
```
