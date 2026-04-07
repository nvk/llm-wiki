---
description: "Retract a source from the wiki. Removes the raw source, identifies all compiled articles that reference it, cleans up references, and flags claims for review. Optionally recompiles affected articles from remaining sources."
argument-hint: "<source-path> [--reason \"why\"] [--recompile] [--dry-run] [--wiki <name>] [--local]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*), Bash(rm:*), Bash(grep:*)
---

## Your task

Retract (remove) a source that was previously ingested into the wiki. This handles the full blast radius: raw source deletion, compiled article cleanup, index updates, and optional recompilation.

### Parse $ARGUMENTS

- **source-path**: Path to the raw source file to retract (e.g., `raw/articles/2026-shitcoiner-article.md`). Can be a filename only — will search raw/ for a match.
- **--reason "why"**: Reason for retraction (logged permanently). Required.
- **--recompile**: After cleanup, recompile affected articles from their remaining sources. Without this flag, articles are cleaned but not resynthesized.
- **--dry-run**: Show what would happen without making changes.
- **--wiki <name>**: Target wiki (same resolution as other commands)
- **--local**: Use project-local `.wiki/`

### Resolve wiki location

First, resolve **HUB** by following the protocol in `references/hub-resolution.md` (read config, expand leading `~` only, quote paths with spaces).

1. `--local` flag → `.wiki/`
2. `--wiki <name>` flag → look up in `HUB/wikis.json`
3. Current directory has `.wiki/` → use it
4. Otherwise → HUB

If the resolved wiki does not exist, stop: "No wiki found."

### Phase 1: Identify the Source

1. If the source-path is a full path (e.g., `raw/articles/2026-shitcoiner.md`), verify it exists
2. If it's a filename or slug, search `raw/` recursively for a match
3. If multiple matches, present them and ask which one
4. Read the source file — extract title, URL, tags, quality, summary
5. Report: "Found: **{title}** ({path}), ingested {date}"

### Phase 2: Map the Blast Radius

Scan ALL compiled wiki articles to find references to this source:

1. **Grep** all files in `wiki/` for the source filename (e.g., `2026-shitcoiner.md`)
2. For each match, classify the reference type:
   - **frontmatter**: Listed in `sources:` field → will be removed
   - **body-inline**: Mentioned or cited in article body text → flag for review
   - **see-also**: Listed in "See Also" or "Sources" section → will be removed
3. Also check `_index.md` files for references

Report the blast radius:
```
Blast radius for "Shitcoiner's Guide to Bitcoin Scaling":

| Article | Reference Types | Impact |
|---------|----------------|--------|
| wiki/concepts/bitcoin-scaling.md | frontmatter + 2 body-inline | HIGH — claims may need rewriting |
| wiki/concepts/lightning-network.md | frontmatter + see-also | LOW — only metadata, no inline claims |
| wiki/topics/layer-2.md | frontmatter + 1 body-inline | MEDIUM — one claim needs review |

Total: 3 articles affected, 3 inline claims to review
```

If `--dry-run`, stop here and report what would happen.

### Phase 3: Clean Up Compiled Articles

For each affected article:

1. **Remove from `sources:` frontmatter** — delete the line referencing the retracted source
2. **Remove from "Sources" section** — delete the link/reference line
3. **Flag inline claims** — for each body-inline reference:
   - Wrap the claim in a retraction marker:
     ```markdown
     <!--RETRACTED-SOURCE: claim below originally sourced from {filename}, retracted {date}: {reason}-->
     [Claim text that needs review]
     <!--/RETRACTED-SOURCE-->
     ```
   - This makes flagged claims visible and searchable without deleting potentially valid information
4. **Update `updated:` date** in frontmatter
5. **Check if article still has sources** — if `sources:` is now empty, flag: "WARNING: {article} has no remaining sources. Consider deleting or recompiling."
6. **Adjust confidence** — if the retracted source was the only high-credibility source, downgrade confidence

### Phase 4: Delete the Raw Source

1. Delete the raw source file
2. Remove its entry from `raw/{type}/_index.md`
3. Decrement source count in `raw/_index.md`
4. Decrement source count in master `_index.md`

### Phase 5: Log the Retraction

Append to `log.md`:
```
## [YYYY-MM-DD] retract | "{title}" — reason: {reason} → {N} articles affected, {N} claims flagged for review
```

Append same to hub `HUB/log.md`.

### Phase 6: Optional Recompile (--recompile)

If `--recompile` is set, for each affected article with body-inline claims:

1. Read the article's remaining sources (from updated `sources:` frontmatter)
2. Re-read each remaining raw source file
3. Rewrite the flagged sections using only the remaining sources
4. Remove the `<!--RETRACTED-SOURCE-->` markers
5. If no remaining sources cover the claim, delete it entirely and note the deletion
6. Update the article's `updated:` date

Report:
```
Recompiled 2 articles:
- bitcoin-scaling.md: 2 claims rewritten from remaining sources, 0 claims removed
- layer-2.md: 0 claims rewritten, 1 claim removed (no other source covers this)
```

### Phase 7: Final Report

```markdown
## Retraction Complete

**Source retracted**: {title} ({path})
**Reason**: {reason}
**Date**: YYYY-MM-DD

### Impact
- Articles affected: N
- Inline claims flagged: N
- Claims recompiled: N (if --recompile)
- Claims removed: N (if --recompile, no remaining source)

### Articles Modified
| Article | Changes |
|---------|---------|
| {path} | Removed from sources, {N} claims flagged/rewritten |

### Remaining Review Items
- [ ] {article}: review claim at line {N} (flagged but not recompiled)

### Verification
Run `/wiki:lint` to verify no dangling references remain.
```

### Edge Cases

- **Source used by 0 articles**: Just delete it, update indexes, log it. No article cleanup needed.
- **Source is the ONLY source for an article**: Warn prominently. With `--recompile`, the article would be gutted. Recommend deletion instead: "Article {name} has no remaining sources after retraction. Consider `/wiki:retract` on the article itself, or manually rewriting with new sources."
- **Multiple sources to retract**: Run retract once per source. Each run is atomic and logged independently.
- **Retracted source referenced in another raw source**: Raw sources are immutable — don't modify them. Only compiled articles are cleaned up.
