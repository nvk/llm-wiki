---
description: "Ask read-only questions against the wiki. Supports quick, standard, deep, list, archived, supplementary-wiki, and resume modes with exact file citations."
argument-hint: "<question> [--quick|--deep] [--raw] [--list] [--include-archived] [--resume] [--tag <tag>] [--category concepts|topics|references] [--with <wiki>...] [--wiki <name>] [--local]"
allowed-tools: Read, Glob, Grep
---

# Read-Only Wiki Query

Read `skills/wiki-manager/references/query-lite.md`, then answer `$ARGUMENTS`
from the selected wiki. This command is always read-only: do not update indexes
or append to `log.md`.

## Parse

- Everything that is not a flag is the question.
- `--quick`: use index summaries only.
- No depth flag: standard index-first query.
- `--deep`: inspect all relevant compiled articles, links, and raw evidence.
- `--raw`: allow targeted raw-source reads; implied by `--deep`.
- `--list`: return ranked matching files instead of a synthesized answer.
- `--include-archived`: explicitly permit archived reads and label them.
- `--resume`: give a compact activity briefing before answering any question.
- `--tag` and `--category`: constrain candidate selection.
- `--with <wiki>`: use an active supplementary wiki as secondary context.
- `--wiki <name>` and `--local`: select the primary wiki.

## Depth

### Quick

Read the primary `_index.md` and only the relevant branch indexes. Answer from
their summaries and tags. If they are insufficient, say so and recommend the
standard mode. Cite the index paths used.

### Standard

Use the query-lite protocol: master index, relevant branch index, then the
minimum exact articles. Use one bounded Grep only when indexes miss a likely
match. Follow directly relevant See Also links. Cite exact files and surface
confidence or evidence gaps that affect the answer.

### Deep

Read all relevant branch indexes and articles, follow relevant cross-links,
search `wiki/` and `raw/` with bounded patterns, and inspect active sibling
indexes for overlap. Archived sibling indexes may be reported separately, but
archived article bodies require `--include-archived`. See query-lite.md's
Evidence Rules for the optional `scripts/morph-compact` step on long `raw/`
reads -- best-effort only, never required.

## List Mode

Return a compact ranked list. Rank title matches above summary matches, summary
above body matches, and multiple-term matches above single-term matches. Show
title, exact path, summary, and tags. Include raw matches only with `--raw`.
Keep archived results separate and only include them when explicitly allowed.

## Resume Mode

Start with `<wiki-name> booted from <wiki-root-path>`. Read only the active
session/checkpoint files, the recent tail of `log.md`, the master index stats,
and the three most recently updated index entries. Report interrupted work,
recent activity, stats, recent articles, and concrete next steps. If a question
is present, answer it afterward using standard depth.

## Supplementary and Archived Wikis

The primary wiki provides the subject. `--with` wikis provide secondary craft
or domain context and must remain clearly attributed. Reject archived primary
or supplementary targets unless `--include-archived` is present. Label every
archived citation.

## Output

Answer directly with exact file citations. For standard or deep answers, add
short `Sources used` and `Knowledge gaps` sections only when useful. For list
or resume-only output, omit those sections. Never use training data to fill a
wiki gap and never mutate the wiki while answering.
