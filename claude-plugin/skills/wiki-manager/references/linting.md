# Linting Rules

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
```
