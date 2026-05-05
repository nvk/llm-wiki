# Inventory Reference

Inventory is a wiki-owned tracking layer for durable "things we care about" that
are not necessarily raw sources, compiled articles, or output artifacts. It is
for ingest candidates, entities, corpora, open questions, recurring tasks, watch
items, and other records the user wants the wiki to remember and revisit.

Inventory records are markdown files with frontmatter. They can cite `raw/`,
`wiki/`, `output/`, URLs, or external paths, but they do not move or copy those
artifacts.

## Directory Layout

Inventory lives at the wiki root:

```text
inventory/
├── _index.md
├── candidates/
│   ├── _index.md
│   └── *.md
├── entities/
│   ├── _index.md
│   └── *.md
├── corpora/
│   ├── _index.md
│   └── *.md
└── views/
    ├── _index.md
    └── *.md
```

The subdirectories are intentionally broad:

- `candidates/`: ingest candidates, open questions, tasks, watch items, and
  proposed follow-up work.
- `entities/`: people, organizations, projects, venues, standards bodies, or
  other named things worth tracking.
- `corpora/`: source collections, archives, datasets, forums, document sets, or
  other bounded bodies of material.
- `views/`: generated inventory views such as "P0 blocked candidates" or
  "active corpora by license." Views are derived and may be regenerated.

## Record Format

```markdown
---
title: "Bitcointalk Schnoering Figshare Dataset"
kind: corpus
status: proposed
priority: p0
created: YYYY-MM-DD
updated: YYYY-MM-DD
last_checked: YYYY-MM-DD
next_action: "Profile archive contents and decide dataset registry location."
sources:
  - output/bitcointalk-data-2026-05-03.md
  - https://figshare.com/articles/dataset/BitcoinTemporalGraph/26305093
tags: [bitcointalk, dataset, ingest-candidate]
confidence: medium
summary: "Large Bitcointalk corpus candidate identified during research."
---

# Bitcointalk Schnoering Figshare Dataset

## Why Track This

...

## Current State

...

## Next Action

...

## Notes

...
```

Required fields:

- `title`
- `kind`
- `status`
- `priority`
- `created`
- `updated`
- `tags`
- `summary`

Recommended fields:

- `last_checked`
- `next_action`
- `sources`
- `confidence`
- `origin` for migrated records
- `owner` if a human or project owns the next action

Kinds:

- `ingest-candidate`
- `entity`
- `corpus`
- `question`
- `task`
- `artifact`
- `watch`

Statuses:

- `proposed`: discovered, not accepted yet
- `active`: accepted and being tracked
- `blocked`: cannot proceed until a dependency is resolved
- `ingested`: completed as a raw/wiki ingest or equivalent action
- `superseded`: replaced by a better record/source
- `archived`: no longer active but retained for history

Priorities:

- `p0`: highest leverage or urgent
- `p1`: important
- `p2`: useful
- `p3`: low priority
- `p4`: keep for completeness

## Index Format

`inventory/_index.md` should summarize counts and link to category indexes:

```markdown
# Inventory Index

> Durable tracking records for candidates, entities, corpora, and watch items.

Last updated: YYYY-MM-DD

## Statistics

- Total records: N
- Candidates: N
- Entities: N
- Corpora: N
- Active: N
- Blocked: N

## Quick Navigation

- [Candidates](candidates/_index.md)
- [Entities](entities/_index.md)
- [Corpora](corpora/_index.md)
- [Views](views/_index.md)

## Contents

| File | Kind | Status | Priority | Next Action | Updated |
|------|------|--------|----------|-------------|---------|
```

Subdirectory indexes use the same table shape. Indexes are derived caches; the
frontmatter in inventory record files is authoritative.

## Migration Paths

Inventory migration is explicit and additive. Do not move or delete existing
outputs during migration.

### Discovery

`inventory scan-outputs` looks for output files that are really durable tracking
records:

- filenames containing `queue`, `backlog`, `inventory`, `candidate`, `watch`,
  `sources`, `corpus`, or `dataset`
- titles containing those terms
- tables with URL/source/status/priority/next-action columns

It reports suggested `inventory migrate-output ... --apply` commands. It must
not write inventory files.

### Output Migration

`inventory migrate-output <path>` defaults to dry-run. It reads the output and
proposes one or more inventory records with:

- `origin: output/...`
- `sources:` pointing at the original output and any cited URLs/files
- inferred `kind`, `status`, and `priority`
- body sections preserving useful rationale and next actions

`--apply` writes new inventory records but still leaves the original output in
place. Cleanup of legacy outputs is a later human decision.

## Lint Behavior

Lint should treat missing `inventory/` as a migration opportunity for older
wikis, not as corruption:

- Missing `inventory/` on an existing wiki: suggestion, not critical.
- `lint --fix`: may create empty inventory directories and indexes only.
- Output files that look like inventory: suggestion with migration commands.
- Lint must never auto-convert output artifacts into inventory records.

## Relationship To Other Layers

- `raw/`: immutable ingested source content.
- `wiki/`: synthesized knowledge articles.
- `output/`: generated deliverables.
- `inventory/`: durable tracking records and next-action state.

Inventory records can point at all three other layers, but they do not replace
them.
