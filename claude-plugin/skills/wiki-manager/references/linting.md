# Linting Rules

## Development Note — Lint is the Migration

**When you change the canonical structure or frontmatter schema, update the rules in this file and in `compilation.md` — do NOT write migration code.**

The wiki treats "file in the wrong place from an old version" and "file in the wrong place from user error" as the same defect. `/wiki:lint --fix` heals both, idempotently. Indexes are already derived caches (see `indexing.md` Derived Index Protocol) — this principle extends to file placement and frontmatter shape.

There are two layers where this principle applies, each with its own rules:

- **Mechanical layer (C11/C12/C13)** — raw-source and wiki-article placement and frontmatter schema. Fully auto-fixable because the canonical location and field shape are pure functions of frontmatter. No judgment required.
- **Editorial layer (C8/C9)** — project grouping inside `output/projects/`. **Never auto-fixed** because "these files belong together" requires human sense-making. C9 surfaces candidates and emits ready-to-paste `/wiki:project new` + `/wiki:project add` blocks for the user to run.
- **Inventory layer (C16)** — durable tracking records under `inventory/`.
  Inventory is lazy: a completely absent inventory tree is a suggestion, not
  something to auto-populate with empty placeholders. Partially existing
  inventory structure is repairable. Migrating old queue-like outputs into
  inventory records is human-gated.
- **Dataset layer (C17)** — dataset manifests under `datasets/`.
  Datasets are lazy: a completely absent registry is a suggestion, not
  something to auto-populate with empty placeholders. Partially existing
  registry structure is repairable. Converting outputs or raw data into dataset
  manifests is human-gated.
- **Archive lifecycle (C19)** — topic wiki lifecycle under
  `HUB/topics/.archive/`. Archive is quiet preservation: normal lint reports
  archived topics as skipped, while `--include-archived` or `--archived-only`
  can structurally maintain them without creating freshness or compilation
  chores.

Concretely, when evolving the schema:

- **Renamed a `raw/`, `wiki/`, `inventory/`, or `datasets/` directory?** Update the placement map in C11/C16/C17 and the allowlist in C12. Every existing wiki self-heals on the next lint.
- **Renamed a frontmatter field?** Append an entry to C13's alias table (old → new). Never remove old aliases.
- **Changed an enum value?** Add a value alias in C13. Never remove old values.
- **Added a required field?** Add it to C2 and give it an inference rule (derive from body/filename) or a sane default.
- **New directory under `raw/`, `wiki/`, `inventory/`, `datasets/`, or hub topic lifecycle paths?** Add it to C12/C19's allowlists and C11/C16/C17/C19's placement maps.
- **New project-level structure or manifest rule?** Update C8 (and projects.md). Candidate heuristics go in C9.

There is no `/wiki:migrate` command and there should never be one. Lint rules **are** the schema.

**When editing the canonical spec** (`wiki-structure.md`, `compilation.md`, `ingestion.md`, `projects.md`, or any reference that defines paths or frontmatter fields), also:

1. Update the relevant check(s) in this file — mechanical changes touch C11/C12/C13; project-model changes touch C8/C9; topic lifecycle changes touch C19.
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
- [ ] `schema.md` exists. Missing topic guide is an Info-level adoption prompt
  for older wikis, not a structural failure.
- [ ] Every existing wiki-managed subdirectory under `raw/`, `wiki/`, `inventory/`, and `datasets/` has `_index.md` where applicable. Optional lazy roots that are completely absent are not C1 failures.
- [ ] `output/` has `_index.md`
- [ ] Every `.md` file (excluding `_index.md` and `config.md`) has valid YAML frontmatter delimited by `---`
- [ ] Hub `topics/.archive/`, when present, contains only archived topic
  directories. Archived topic roots still have their own `_index.md`, but
  normal topic lint skips them unless explicitly included.
- [ ] Optional hub `.skills/`, when present, has `_index.md`, schema-v1
  `registry.json`, and valid instruction-only specialist packages. Package
  names/frontmatter match; required method sections exist; allowlists reference
  valid specialists and active topics; symlinks, executable files, scripts,
  binaries, and undeclared package paths fail validation.

### C2: Frontmatter (Critical/Warning)

- [ ] Every raw source has: title, source, type, ingested, tags, summary
- [ ] Every wiki article has: title, category, created, updated, tags, summary, plus either `sources` or `compiled-from: conversation`
- [ ] No empty title or summary fields
- [ ] `category` is one of: concept, topic, reference
- [ ] `type` is one of: articles, papers, repos, notes, data
- [ ] `tags` is a list, not empty
- [ ] `compiled-from`, when present, is one of: sources, conversation, mixed
- [ ] Optional collection provenance fields are valid when present:
  `collection`, `adapter`, `upstream_id`, `upstream_type`, `revision`, `sha`,
  `canonical_url`, `content_format`, `license`, `authors`, `categories`,
  `outlinks`, `fetched`

### C3: Index Consistency (Warning)

- [ ] Index shape is declared by directory contract, never inferred from the
  current `_index.md` text:
  - `raw/_index.md` and `wiki/_index.md`: category-index pointers
  - `inventory/_index.md`: category navigation plus a nested record rollup
  - `datasets/_index.md`: dataset manifest registry
  - `output/_index.md`: loose output and active Project `WHY.md` listing
  - leaf directories: direct-file tables
- [ ] Every contract entry appears as a local markdown link in its owning
  `_index.md`; a record rollup cannot be hidden by otherwise-valid navigation
- [ ] No `_index.md` references a non-existent file (dead entries)
- [ ] Statistics in master `_index.md` match actual file counts
- [ ] "Last compiled" and "Last lint" dates are present and valid

### C4: Link Integrity (Warning)

- [ ] All markdown links `[text](path)` in wiki articles and inventory records
  resolve to existing local files when they are local paths
- [ ] Do not apply this check to raw source bodies. Imported Markdown may retain
  relative links whose targets live only in the upstream source collection.
- [ ] All "See Also" links are bidirectional (if A→B, then B→A)
- [ ] All "Sources" links in wiki articles point to existing raw files. Links to paths with spaces should use angle-bracket markdown destinations, e.g. `[Title](<../../raw/articles/File Name.md>)`.

### C4b: Source Provenance (Warning)

- [ ] All `sources:` entries in wiki article frontmatter point to existing raw files (no dangling references to deleted/retracted sources). Resolve entries with the Source Reference Resolution protocol in `wiki-structure.md`: parse the full YAML scalar/path, preserve whitespace, exact path first, then slug fallback. Never split on whitespace.
- [ ] All local `sources:` entries in inventory record frontmatter point to
  existing files under `raw/`, `wiki/`, `output/`, `datasets/`, or `inventory/`.
  External URLs are allowed. Inventory provenance is operational state and must
  not be treated as factual evidence for compile/query/audit verdicts.
- [ ] Explicit local paths in a raw source's scalar `source:` field resolve to
  an existing file or directory. Treat absolute paths, `file://` URIs,
  `./`/`../`/`~/` paths, and whitespace-free relative paths containing a
  directory separator as local. Other URI schemes, schemeless web URLs,
  sentinels such as `MANUAL` or `session`, and free-form provenance labels are
  not local-path checks.
- [ ] No `<!--RETRACTED-SOURCE-->` markers remain in article body (these should be resolved via `--recompile` or manual review)
- [ ] No raw source file is referenced by zero wiki articles (orphan source — suggest compilation or removal)
- [ ] Exempt raw files tagged `collection-manifest` from orphan-source warnings. A collection manifest is operational provenance for a batch import; child sources should be compiled, but the manifest itself does not need to appear in article `sources:`.

### C5: Tag Hygiene (Warning)

- [ ] No near-duplicate tags (e.g., `ml` and `machine-learning`, `nlp` and `natural-language-processing`)
- [ ] Tags in article frontmatter match tags listed in `_index.md` entries
- [ ] Suggest canonical tag when duplicates found

### C6: Coverage (Suggestion)

- [ ] Every raw source is referenced by at least one wiki article's `sources` field
- [ ] Raw sources tagged `collection-manifest` are exempt from this coverage check
- [ ] No wiki article has an empty `sources` field (C18 covers the per-article enforcement at Warning severity; this bullet stays as the wiki-wide coverage signal at Suggestion)
- [ ] With `--fix`, create or update `wiki/references/uncompiled-source-coverage.md` when raw sources are otherwise unreferenced. This makes the coverage gap explicit as a compilation backlog; it is not a claim that the source has been fully synthesized elsewhere.
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
- [ ] **C8b** Staleness check — for every project, compute transitive source freshness (**Suggestion**). For each member file with `sources:` frontmatter, follow the chain to raw sources using the Source Reference Resolution protocol in `wiki-structure.md`. If any raw source's `ingested:` date is newer than the member's `updated:` date, the project may be stale. Report as: `Project <slug> may be stale: N source(s) newer than member artifacts.` Never auto-fixed — staleness triggers human re-evaluation, not automatic regeneration.

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

Any file that is not in the canonical allowlist for its location is either a user mistake, a stale artifact from an older wiki version, or a legitimate new kind of thing that the schema hasn't caught up to. Lint surfaces it either way. Like C11, this is scoped to `raw/`, `wiki/`, `inventory/`, `datasets/`, and the wiki root — not `output/projects/` (C8 handles that).

**Allowlists** (per location):

| Location | Allowed items |
|----------|--------------|
| HUB | `wikis.json`, `_index.md`, `README.md`, `log.md`, `topics/`, optional `.sessions/`, optional `.skills/` |
| `HUB/.skills/` | `_index.md`, `registry.json`, and lowercase specialist package directories |
| `HUB/.skills/<name>/` | `SKILL.md` and optional `references/` containing Markdown only |
| `HUB/topics/` | active topic directories plus `.archive/` |
| `HUB/topics/.archive/` | archived topic directories |
| Topic wiki root | `_index.md`, `README.md`, `config.md`, `schema.md`, `log.md`, `raw/`, `wiki/`, `inventory/`, `datasets/`, `output/`, `inbox/`, `.obsidian/`, `.librarian/`, `.audit/`, `.research-session.json`, `.thesis-session.json`, `.session-events.jsonl`, `.session-checkpoint.json` |
| `raw/` | `_index.md`, `articles/`, `papers/`, `repos/`, `notes/`, `data/` |
| `wiki/` | `_index.md`, `concepts/`, `topics/`, `references/`, `theses/` |
| `inventory/` | `_index.md`, `items/`, `ideas/`, `candidates/`, `entities/`, `corpora/`, `views/` |
| `datasets/` | `_index.md` + dataset slug directories |
| `raw/<type>/` | `_index.md` + `*.md` files with valid frontmatter |
| `wiki/<category>/` | `_index.md` + `*.md` files with valid frontmatter |
| `inventory/{items,ideas,candidates,entities,corpora}/` | `_index.md` + `*.md` files with valid inventory record frontmatter |
| `inventory/views/` | `_index.md` + derived `*.md` view files with lightweight view frontmatter |
| `datasets/<slug>/` | `_index.md`, `MANIFEST.md`, `samples/`, `profiles/`, `queries/` |
| `datasets/<slug>/{samples,profiles,queries}/` | `_index.md` + `*.md` notes |
| `inbox/` | `.processed/`, `.unknown/`, user-dropped files |

When the hub or topic wiki root is itself a Git repository root (a `.git`
directory or worktree `.git` file exists there), also allow the repository's
`.git`, optional `.github/`, `AGENTS.md`, `CLAUDE.md`, `CHANGELOG.md`,
`CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `SECURITY.md`, `LICENSE`, `LICENSE.md`,
`.gitignore`, `.gitattributes`, and `.gitmodules`. Do not apply this exception
merely because some parent directory is a repository: project metadata does not
belong inside an ordinary nested `.wiki/`.

**Checks**:

- [ ] Walk `raw/`, `wiki/`, `inventory/`, `datasets/`, and the wiki root. For each entry, check against the allowlist for that location.
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

**Canonical optional raw-source keys** (do not warn as unknown):
`collection`, `adapter`, `upstream_id`, `upstream_type`, `revision`, `sha`,
`canonical_url`, `content_format`, `license`, `authors`, `categories`,
`outlinks`, `fetched`.

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

**Auto-fix**: Rewrite the YAML key or value in place using Edit. Preserve field order and comments. For older compiled articles that predate the current article schema, `lint --fix` may also infer missing `category` from the containing directory (`wiki/concepts`, `wiki/topics`, `wiki/references`), infer `summary` from an explicit `**Summary**:` line or the first substantial paragraph, fill missing `created`/`updated` from existing date fields, add `tags: [thesis]` only for thesis files with no tags, and add `volatility: warm`.

**When the tables are empty** (current state), C13 only runs the unknown-key warning — alias rewriting is a no-op. This is the honest default: we have no backward-compat debt yet, so advertising alias entries would be fiction. First real rename → first real alias entry.

### C14: Freshness (Warning/Info)

Computes a composite freshness score (0-100) for each compiled wiki article based on source freshness, verification recency, compilation recency, and source chain integrity. Standard source-backed articles use all four dimensions at 0-25 points each. Articles with `compiled-from: conversation` have no fetchable raw source chain, so they skip source freshness and source chain integrity, compute verification recency and compilation recency at 0-25 points each, then multiply the 50-point subtotal by 2. Decay curves are scaled by the article's `volatility` tier. See `wiki-structure.md` § Freshness Score for the full formula.

- [ ] For each wiki article with `volatility` and `verified` fields, compute the standard four-dimension composite score, or the rebased two-dimension score when `compiled-from: conversation`
- [ ] Read `freshness_threshold` from `config.md` (default: 70 if not set)
- [ ] Flag articles scoring below the threshold

**Severity**: Warning for `hot` and `warm` articles below threshold. Info for `cold` articles below threshold (Lindy Effect — cold content scoring low is unusual and worth noting, but rarely urgent).

**Output**: `Freshness score [score]/100: [article] — source age [avg days], verified [days] ago, compiled [days] ago, [N/M] sources intact. Run /wiki:refresh [path]`

For `compiled-from: conversation` articles, use: `Freshness score [score]/100: [article] — conversation-sourced, verified [days] ago, compiled [days] ago. Review or re-verify manually.`

**Auto-fix**: None. Freshness requires human judgment — automated recompilation risks the "confident wrong answer" problem where stale content is replaced by hallucinated content.

### C15: Missing Volatility (Info)

Flags wiki articles that lack the `volatility` field. New articles should always have volatility set during compilation.

- [ ] For each `.md` file in `wiki/` (excluding `_index.md`), check for `volatility` field in frontmatter
- [ ] Flag files missing the field

**Severity**: Info (not blocking — existing wikis predate this field).

**Auto-fix**: Add `volatility: warm` as the safe default that puts the article into the standard monitoring cadence. Do not invent a `verified:` date unless verification was actually performed; use existing `updated:`/`verified:` dates only for freshness scoring.

### C16: Inventory Structure and Migration Candidates (Suggestion)

Validates the optional-but-first-class `inventory/` layer. New or older wikis
may lack this directory; that is a migration opportunity, not corruption, and
lint should not create a blank inventory tree unless part of the layer already
exists.

- [ ] If `inventory/` is missing entirely, report "no inventory layer yet" as a suggestion.
- [ ] If `inventory/` exists, it has `_index.md`.
- [ ] If any inventory subdirectory exists, it has `_index.md`.
- [ ] Inventory records under `inventory/items/`, `inventory/ideas/`,
  `inventory/candidates/`, `inventory/entities/`, and `inventory/corpora/` have valid frontmatter when present:
  `title`, `kind`, `status`, `priority`, `created`, `updated`, `tags`,
  `summary`
- [ ] Inventory view files under `inventory/views/` have lightweight view
  frontmatter when present: `title`, `view`, `updated`, `summary`
- [ ] `kind` is one of: `item`, `idea`, `ingest-candidate`, `entity`, `corpus`,
  `question`, `task`, `artifact`, `watch`
- [ ] `kind: idea` records live in `inventory/ideas/`. Their optional
  `approved_at`, `promoted`, and `project` fields follow `ideas.md`; lint does
  not infer approval, create a Project, or add a manual maturity stage.
- [ ] `status` is one of: `proposed`, `active`, `blocked`, `ingested`,
  `superseded`, `archived`
- [ ] `priority` is one of: `p0`, `p1`, `p2`, `p3`, `p4`
- [ ] Loose output artifacts that look like durable tracking records are
  reported as inventory migration candidates. Heuristics: filename or title
  contains `queue`, `backlog`, `inventory`, `candidate`, `watch`, `sources`,
  `corpus`, or `dataset`; body has repeated URL/source/status/priority/next
  action tables.

**Auto-fix**:

- With `--fix`, repair missing indexes for an inventory layer or subdirectory
  that already exists. Do not create `inventory/` when it is completely absent,
  and do not create empty category folders that are not needed by existing
  records.
- With `--fix`, regenerate `inventory/views/_index.md` from saved view
  frontmatter when `inventory/views/` exists, but do not fabricate saved views.
- Never auto-convert output artifacts into inventory records. Report suggested
  commands such as:
  `/wiki:inventory migrate-output output/ingest-queue-2026-05-03.md --kind ingest-candidate --dry-run`
- When reporting candidates, include a short fit note: good inventory fit, too
  small and better left as query/ingest/raw note, or too large and better as a
  dataset manifest or collection ingest. For high-confidence pivots, show a
  sample record shape before suggesting `--apply`.

### C17: Dataset Registry Structure and Migration Candidates (Suggestion)

Validates the optional-but-first-class `datasets/` registry for large or
external data. New or older wikis may lack this directory; that is a migration
opportunity, not corruption, and lint should not create a blank registry unless
part of the layer already exists.

- [ ] If `datasets/` is missing entirely, report "no dataset registry yet" as a suggestion.
- [ ] If `datasets/` exists, it has `_index.md`.
- [ ] Every `datasets/<slug>/` directory has `_index.md` and `MANIFEST.md`
- [ ] If a dataset folder has `samples/`, `profiles/`, or `queries/`, those
  subdirectories have `_index.md`. Missing sample/profile/query folders are fine
  until used.
- [ ] Dataset manifests have valid frontmatter:
  `title`, `dataset_id`, `status`, `storage`, `locations`, `formats`,
  `schema_status`, `created`, `updated`, `tags`, `summary`
- [ ] `status` is one of: `proposed`, `active`, `external`, `archived`,
  `unavailable`
- [ ] `storage` is one of: `local`, `remote`, `external`, `hybrid`
- [ ] `schema_status` is one of: `unknown`, `inferred`, `declared`,
  `validated`
- [ ] Loose output artifacts that look like dataset descriptions are reported
  as dataset migration candidates. Heuristics: filename or title contains
  `dataset`, `data`, `corpus`, `archive`, `dump`, `warehouse`, `lake`,
  `parquet`, `sqlite`, `duckdb`, `csv`, `jsonl`, or `snapshot`; body has size,
  rows, schema, storage path, license, sample, or query recipe sections.

**Auto-fix**:

- With `--fix`, repair missing indexes for a dataset registry or subdirectory
  that already exists. Do not create `datasets/` when it is completely absent,
  and do not create empty `samples/`, `profiles/`, or `queries/` folders until
  they are needed.
- Never auto-convert output artifacts, raw data files, or inventory records into
  dataset manifests. Report suggested commands such as:
  `/wiki:dataset migrate-output output/bitcointalk-data-2026-05-03.md --dry-run`

### C18: Missing Sources (Warning)

Wiki articles that lack `sources:` in their frontmatter — or carry an empty list — cannot have their source-chain integrity scored, which leaves them stuck near the freshness floor regardless of how recently they were verified or compiled. The compile protocol already requires non-empty `sources:` for articles compiled from raw files (see `compilation.md` step 5.6); C18 is the runtime check that catches articles where compile skipped this step.

The exemption is `compiled-from: conversation` — articles whose evidence is the conversation that authored them rather than fetchable raw files. This frontmatter value is the legitimate signal that the article will never have raw sources and should be scored against verification recency only (see `librarian.md` § Staleness Scoring for the matching exemption in the score formula).

- [ ] For each `.md` file in `wiki/` (excluding `_index.md`), check that frontmatter has either:
  - A non-empty `sources:` list with at least one entry that resolves under the Source Reference Resolution protocol in `wiki-structure.md`, OR
  - `compiled-from: conversation` set explicitly
- [ ] Flag any file that has neither.

**Severity**: Warning (not Critical — the article is still readable and may be substantively correct; but it will silently fail the freshness composite until fixed).

**Auto-fix**: None. Wiring sources requires reading the article body, identifying its origin raw files, and writing accurate paths — not a default-fillable. Surface the file with a one-line suggestion: `Compiled article <path> has no sources. Recompile the relevant raw source with /wiki:compile --source <raw-source-path>, run /wiki:compile --full, OR add 'compiled-from: conversation' if this article was authored from chat without fetchable sources.`

**Output line**: `Compiled article missing sources: <path>. (C18)`

### C19: Archive Lifecycle and Registry (Warning/Suggestion)

Validates the hub-level archive lifecycle described in `archive.md`.

- [ ] `HUB/topics/.archive/` may exist and is not an unknown directory.
- [ ] Archived topic directories have `_index.md`, `config.md`, `log.md`, and
  normal topic wiki structure when checked with `--include-archived` or
  `--archived-only`.
- [ ] `wikis.json` entries whose path starts `topics/.archive/` have
  `status: archived`.
- [ ] `wikis.json` entries with `status: archived` point to an existing
  `topics/.archive/<slug>` directory, or lint reports the stale registry entry.
- [ ] Active registry entries do not point into `topics/.archive/`.
- [ ] If `HUB/topics/.archive/<slug>/_index.md` exists but the registry is
  missing the topic, report a registry repair candidate.
- [ ] If both `HUB/topics/<slug>` and `HUB/topics/.archive/<slug>` exist,
  report a lifecycle collision and never choose automatically.
- [ ] Active articles or outputs that cite archived raw/wiki/output paths are
  surfaced as boundary-crossing provenance warnings. This is allowed but should
  be visible.

**Default behavior**:

- Normal hub lint reports `Archived topics: N skipped` and does not recursively
  inspect archived topic content.
- Normal topic lint has no archive behavior unless the target topic path itself
  is archived, in which case the command should ask for `--include-archived` or
  `--archived-only`.

**Auto-fix**:

- With `--fix`, repair unambiguous registry drift:
  - archived directory exists, registry path stale/missing -> set
    `path: topics/.archive/<slug>` and `status: archived`
  - active directory exists, archived directory absent, registry says archived
    -> set `path: topics/<slug>` and `status: active`
- Do not move a topic into or out of archive during lint. Archive and restore
  are explicit lifecycle operations.
- Do not auto-resolve active/archive collisions.

## Auto-Fix Rules (when --fix is set)

| Issue | Auto-Fix Action |
|-------|----------------|
| Missing `_index.md` | Generate using its declared directory contract and renderer |
| File not in index | Regenerate with the declared contract; preserve root navigation and domain-specific tables |
| Dead index entry | Regenerate with the declared contract, dropping only dead contract rows/links |
| Statistics mismatch | Recalculate from actual file counts |
| Raw sources with no compiled reference | Create/update `wiki/references/uncompiled-source-coverage.md` as an explicit synthesis backlog |
| Missing bidirectional link | Add "See Also" entry to the article missing the backlink |
| Empty frontmatter field | Infer safe schema fields where possible: category from directory, summary from explicit summary/first paragraph, dates from existing frontmatter |
| Near-duplicate tags | Replace all instances with the canonical form |
| Fuzzy or dangling source reference | If exact path resolution fails but slug fallback resolves to exactly one raw file, rewrite to that exact `raw/...md` path. If resolution still fails or is ambiguous, warn for human review; never auto-remove provenance entries |
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
| **C13** Older compiled article missing safe schema fields | Infer `category`, `summary`, `created`, `updated`, `tags` for theses, and `volatility` as described above |
| **C14** Article below freshness score threshold | **Warn/Info only** — composite score below `freshness_threshold` (default 70). Report score breakdown and suggest `/wiki:refresh`. |
| **C15** Missing volatility field | Add `volatility: warm` — safe default |
| Missing `schema.md` | Add a default human-owned `schema_state: advisory` starter topic guide; existing content is unchanged |
| **C16** Missing inventory directories/indexes | Repair missing indexes for existing inventory directories; do not create a completely absent inventory tree or empty unused category folders |
| **C16** Output looks like inventory | Warn only — suggest `/wiki:inventory migrate-output <path> --dry-run`; never auto-migrate |
| **C17** Missing dataset registry directories/indexes | Repair missing indexes for existing dataset directories; do not create a completely absent dataset tree or empty unused sample/profile/query folders |
| **C17** Output looks like a dataset manifest | Warn only — suggest `/wiki:dataset migrate-output <path> --dry-run`; never auto-migrate |
| **C18** Compiled article missing sources | **Warn only** — surface with the suggested commands. Do not auto-add `compiled-from: conversation` (that's a provenance claim that requires human judgment) and do not auto-recompile (would synthesize fake sources). |
| **C19** Archived topic registry drift | Repair only unambiguous `wikis.json` path/status drift. Do not move topic directories during lint |
| **C19** Active/archive topic collision | Warn only — user must decide which directory wins |

## Report Format

**User-facing output must lead with plain-English descriptions, not check codes.** The C-codes (C1, C8c, C11, etc.) are internal identifiers for cross-referencing between this file and `commands/lint.md`. They must never appear as the leading text in any line the user sees. If a code is useful for debugging, append it in parentheses at the end — but prefer omitting it entirely.

```markdown
## Wiki Lint Report — YYYY-MM-DD

### Summary
- Ran N health checks
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
- Missing project rationale (WHY.md): [list of slugs]
- Possibly stale (sources newer than artifacts): [list of slugs with source-count diff]
- Migrated legacy manifests (_project.md → WHY.md): [list of slugs]

### Project Candidates
- [grouped suggestions, formatted as the candidate report block above]

### Inventory
- Inventory records: [count by kind/status]
- Missing inventory structure created: [yes/no]
- Output artifacts that look like inventory: [list with suggested migrate-output commands]

### Datasets
- Dataset manifests: [count by status/storage]
- Missing dataset registry structure created: [yes/no]
- Dataset manifest/schema issues: [list]
- Output artifacts that look like datasets: [list with suggested migrate-output commands]

### File Placement & Schema
- Misplaced files moved to canonical location: [count, list of moves as `old → new`]
- Unknown files quarantined to inbox: [count, list of moves to `inbox/.unknown/`]
- Legacy frontmatter keys updated: [count by alias]
- Legacy enum values updated: [count by alias]
- Unknown directories (not auto-deleted): [list]

### Archive
- Archived topics skipped by default: [count]
- Archived topics checked: [count, only when explicitly included]
- Registry lifecycle repairs: [list]
- Active/archive collisions: [list]
```
