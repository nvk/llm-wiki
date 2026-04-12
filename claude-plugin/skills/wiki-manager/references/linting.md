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

### C8: Project Hygiene (Critical/Warning)

Validates projects that already exist under `output/projects/`. See `references/projects.md` for the full architecture.

- [ ] **C8a** Every `output/projects/<slug>/_project.md` has required frontmatter: `type: project-manifest`, `goal` (non-empty), `status` ∈ {active, archived, retracted}, `created`, `updated` (**Critical** if missing or invalid)
- [ ] **C8b** Every `_project.md` has both `<!-- DERIVED -->` and `<!-- /DERIVED -->` delimiter comments in its Members section (**Critical** — without these, regeneration is disabled)
- [ ] **C8c** Every markdown file inside `output/projects/<slug>/` (excluding `_project.md`) has `project: <slug>` in its frontmatter (**Warning**). Binary files (`.png`, `.jpg`, `.pdf`, `.csv`, `.json`, `.zip`, `.svg`) are exempt.
- [ ] **C8d** Members section is fresh — scan the folder recursively (max 3 levels per spec), compare against the list between the DERIVED delimiters; stale if counts differ or any file is missing/extra (**Warning**)
- [ ] **C8e** `project:` frontmatter value inside a file matches its containing folder slug (**Warning** — flag, but do not auto-fix; it usually indicates a file was moved incorrectly)
- [ ] **C8f** Slug conforms to spec: lowercase, hyphen-separated, ≤40 chars, no dates (**Warning**)
- [ ] **C8g** `.wiki-session.json` (if present) references an existing project slug; stale focus is a no-op, not an error

### C9: Project Candidates (Suggestion)

Surfaces loose `output/` content that should be grouped into projects. **Never auto-fixed** — grouping decisions require human judgment.

- [ ] **C9a** Binary assets (`.png`, `.jpg`, `.pdf`, `.csv`, `.svg`, `.zip`) loose directly in `output/` root (not inside `projects/`) — these cannot stay loose per the projects architecture. Propose the likely owning project based on filename prefix. (**Critical** — architecture violation)
- [ ] **C9b** Any loose markdown output in `output/` that shares a basename prefix with a sibling binary (e.g., `article-foo.md` + `article-foo-hero.jpg`) — suggest projectifying the pair. (**Suggestion**)
- [ ] **C9c** ≥3 loose markdown outputs sharing a common slug prefix (e.g., `article-quantum-v1.md`, `article-quantum-v2.md`, `article-quantum-v3.md`) — suggest grouping under a single project. (**Suggestion**)
- [ ] **C9d** Any subdirectory inside `output/` that is NOT `projects/` and contains files — architecture violation, all subdirectories should be under `output/projects/`. (**Critical**)
- [ ] **C9e** **Fallback**: wiki has ≥3 loose markdown outputs in `output/` AND no `output/projects/` folder exists. Even if C9a–c produced no candidate clusters, prefix-based grouping is often too strict to catch topical clusters (e.g., `comparison-foo.md`, `comparison-bar.md`, `test-summary-A.md`, `test-summary-B.md` all belong to one project but share no leading prefix). Report the wiki as **unmigrated** and suggest a default single-project grouping using the wiki's own name as the slug seed. (**Suggestion**)

**Candidate report format** (for C9b / C9c / C9e):

```
### Project Candidates (N)

Suggested: bitcoin-quantum-fud (proposed slug)
  Reason: 5 files share prefix "article-bitcoin-quantum-fud-"
  Files:
    - article-bitcoin-quantum-fud-2026-04-05.md
    - article-bitcoin-quantum-fud-v2-2026-04-06.md
    - article-bitcoin-quantum-fud-v3-2026-04-06.md
    ...
  Create with:
    /wiki:project new bitcoin-quantum-fud "TODO: fill in goal"
    /wiki:project add bitcoin-quantum-fud article-bitcoin-quantum-fud-2026-04-05.md
    ...
```

**Slug derivation heuristic**:
- **C9c**: longest common prefix of ≥3 files, stripped of trailing hyphens, dates (`YYYY-MM-DD`), version tags (`-v\d+`, `-final`, `-release`), and the `article-` / `output-` / `report-` prefixes. If the result is <4 chars or ambiguous, report without a proposed slug and let the user name it.
- **C9e**: use the topic wiki's own slug (from `wikis.json` or the folder name) as the seed. Drop the `-wiki` suffix if present. Example: `hardware-wallet-security` → slug `hardware-wallet-security` or a shortened variant like `hw-wallet-security`. Always present the slug as a suggestion and let the user override — C9e is the lowest-confidence rule.

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
| Topic wiki root | `_index.md`, `config.md`, `log.md`, `raw/`, `wiki/`, `output/`, `inbox/`, `.obsidian/`, `.wiki-session.json`, `.research-session.json`, `.thesis-session.json` |
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
| **C8b** Missing DERIVED delimiters in `_project.md` | **Warn only** — insert delimiters would risk clobbering hand-written content; report and skip |
| **C8c** Missing `project:` frontmatter in file inside `projects/<slug>/` | Add `project: <slug>` as the first key after the opening `---` (preserves other frontmatter). If the file has no frontmatter at all, prepend a minimal block: `project`, `title` (inferred from `#` heading), `type: output` |
| **C8d** Stale `_project.md` Members section | Regenerate between `<!-- DERIVED -->` delimiters per the folder scan rules in `references/projects.md` § "Derived index regeneration". Update the `updated:` frontmatter field to today. |
| **C8e** Mismatched `project:` frontmatter vs folder | **Warn only** — indicates the file was moved without updating metadata; human must confirm whether the file or the frontmatter is wrong |
| Stale `output/_index.md` when `projects/` exists | Regenerate as a projects-aware listing: table of projects from `_project.md` frontmatter (title, goal, status, updated) + any remaining loose outputs beneath |
| **C9** candidates | **Never auto-fix** — moves are human-authored via `/wiki:project new` + `/wiki:project add` |
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
- Active: N | Archived: N | Retracted: N
- Stale manifests (C8d): [list of slugs]
- Frontmatter drift (C8c/C8e): [list]

### Project Candidates
- [grouped suggestions per C9, formatted as the candidate report block above]

### Placement & Schema (C11/C12/C13)
- Files moved (C11): [count, list of moves as `old → new`]
- Files quarantined (C12): [count, list of moves to `inbox/.unknown/`]
- Frontmatter keys rewritten (C13): [count by alias]
- Enum values rewritten (C13): [count by alias]
- Unknown directories (C12, warn-only): [list]
```
