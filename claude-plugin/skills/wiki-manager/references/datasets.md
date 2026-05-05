# Dataset Registry Reference

The dataset registry lets a wiki act as an interface and index for data that is
too large, mutable, sensitive, or operationally awkward to store directly under
`raw/`. The registry stores manifests, schema notes, small samples, profiles,
query recipes, and provenance. The actual dataset stays external.

Use this layer for archives, database dumps, message corpora, blockchain data,
parquet/duckdb/sqlite stores, object-store prefixes, API-backed datasets, or any
source where "ingest the whole thing into markdown" would make the wiki less
usable.

## Boundary

- `raw/data/`: immutable source notes or small single-source data files that can
  reasonably live in the wiki.
- `datasets/`: metadata and interface layer for data that should remain outside
  the wiki.
- `inventory/`: tracking state for whether a dataset matters and what to do
  next. Inventory records may point to dataset manifests.
- `output/`: generated deliverables. Legacy output artifacts that describe
  datasets may be migrated additively into dataset manifests.

Do not copy large datasets into `datasets/`. Store paths, URLs, checksums,
profiles, samples, and query recipes instead.

Be opinionated about the boundary:

- If the data is small, stable, and useful as markdown, ingest it into
  `raw/data/` instead of creating a dataset manifest.
- If the data is large, mutable, remote, sensitive, binary, compressed, or
  better queried in its native format, use a dataset manifest.
- If the user mostly needs next actions or acceptance state for a corpus, create
  or link an inventory record. The dataset manifest answers "where/how is the
  data accessed"; inventory answers "why do we care and what happens next."
- If a proposed dataset would become hundreds of inventory records, create one
  dataset manifest plus one corpus inventory record and show that sample shape
  before asking to apply a larger pivot.

## Chat Views

Dataset commands should make large data feel easy to inspect without loading the
data. A normal `dataset list` should be fast and index-driven.

Rules:

- Read `datasets/_index.md` first.
- For filters or columns not present in the index, read only
  `datasets/*/MANIFEST.md` frontmatter.
- Never open samples, profiles, query notes, or the underlying dataset for a
  plain list operation.
- Default chat output is a compact Markdown table. Use bullets when long paths
  or URLs would dominate the table.
- Cap long lists in chat with `--limit` or a sensible default, then report the
  omitted count and the registry path.

Recommended chat views:

| View | Columns | Use |
|------|---------|-----|
| `summary` | counts by status/storage/schema status, newest manifests | quick status checks |
| `manifests` | dataset, status, storage, formats, size, records, updated | complete compact registry |
| `schema` | dataset, schema status, formats, record count, latest profile | deciding what to profile next |
| `locations` | dataset, storage, access, compact location pointer | finding where the data lives |

If a dataset is linked from an inventory record, include the inventory next
action only when it can be read cheaply from the linked record frontmatter.

## Directory Layout

```text
datasets/
├── _index.md
└── <dataset-slug>/
    ├── _index.md
    ├── MANIFEST.md
    ├── samples/
    │   ├── _index.md
    │   └── *.md
    ├── profiles/
    │   ├── _index.md
    │   └── *.md
    └── queries/
        ├── _index.md
        └── *.md
```

Per-dataset folders are created only when a manifest is added. Older wikis may
have no `datasets/` directory until lint or `/wiki:dataset add` creates it.

## Manifest Format

`datasets/<slug>/MANIFEST.md` is the source of truth:

```markdown
---
title: "Bitcointalk Temporal Graph"
dataset_id: bitcointalk-temporal-graph
status: proposed
storage: external
locations:
  - https://figshare.com/articles/dataset/BitcoinTemporalGraph/26305093
formats: [csv, zip]
size_bytes: null
record_count: null
schema_status: unknown
created: YYYY-MM-DD
updated: YYYY-MM-DD
tags: [bitcoin, bitcointalk, graph-dataset]
summary: "External Bitcointalk graph dataset indexed by the bitcoin wiki."
origin: output/bitcointalk-data-2026-05-03.md
inventory:
  - inventory/corpora/bitcointalk-archive.md
raw_sources:
  - raw/articles/2026-05-03-bitcointalk-data.md
license: unknown
access: public
---

# Bitcointalk Temporal Graph

## Scope

What the dataset covers and what it does not cover.

## Storage Locations

Where the data lives, how stable those locations are, and any access constraints.

## Schema

Known tables, columns, keys, entity relationships, and uncertainty.

## Samples And Profiles

Links to small samples and profile notes in this folder.

## Query Recipes

Links to reproducible ways to inspect the dataset without loading it into the
wiki.

## Caveats

Known gaps, bias, volatility, privacy limits, or operational risks.
```

Required frontmatter fields:

- `title`
- `dataset_id`
- `status`
- `storage`
- `locations`
- `formats`
- `schema_status`
- `created`
- `updated`
- `tags`
- `summary`

Recommended fields:

- `size_bytes`
- `record_count`
- `origin`
- `inventory`
- `raw_sources`
- `license`
- `access`
- `checksum`
- `owner`
- `refresh_cadence`

Statuses:

- `proposed`: identified but not accepted as a maintained dataset interface
- `active`: accepted and currently useful
- `external`: intentionally external with no local copy
- `archived`: retained for history, not actively maintained
- `unavailable`: location is inaccessible or permissions are unresolved

Storage modes:

- `local`: local path outside the wiki
- `remote`: remote URL or object-store location
- `external`: third-party dataset page, API, or repository
- `hybrid`: multiple storage modes

Schema statuses:

- `unknown`: no schema is known yet
- `inferred`: schema inferred from sample/profile
- `declared`: upstream provides schema
- `validated`: schema checked against current data

## Index Format

`datasets/_index.md` summarizes manifests:

```markdown
# Dataset Registry Index

> Dataset manifests for large or external data indexed by this wiki.

Last updated: YYYY-MM-DD

## Statistics

- Datasets: N
- Active: N
- External: N
- Unavailable: N

## Contents

| Dataset | Status | Storage | Formats | Size | Records | Updated |
|---------|--------|---------|---------|------|---------|---------|
| [Bitcointalk Temporal Graph](bitcointalk-temporal-graph/MANIFEST.md) | proposed | external | csv, zip | unknown | unknown | YYYY-MM-DD |
```

Each `datasets/<slug>/_index.md` links to `MANIFEST.md` and the sample/profile/
query indexes. Dataset subdirectory indexes list sample/profile/query notes with
the standard `_index.md` table shape.

## Profiles

Profiles are small markdown notes under `datasets/<slug>/profiles/` that capture
observations such as size, format, row counts, headers, table names, partition
layout, or schema certainty. They should include:

- date profiled
- exact location checked
- commands or query snippets used
- bounded observations only
- privacy/security caveats

Never run an expensive full scan unless the user explicitly asks and the path is
safe to access.

## Samples

Samples are tiny excerpts or sampling recipes under `datasets/<slug>/samples/`.
Default to at most 20 rows. For compressed, remote, private, or very large data,
write a recipe instead of fetching the data.

Do not store secrets, personal data, credentials, or large excerpts in samples.

## Query Recipes

Query recipes under `datasets/<slug>/queries/` document reproducible access
patterns such as DuckDB SQL, sqlite commands, parquet scans, API calls, or
Python snippets. Recipes should prefer read-only queries and include expected
runtime/cost when known.

## Migration Paths

Dataset migration is explicit and additive.

### Discovery

`dataset scan-outputs` looks for output files that are really dataset
descriptions:

- filenames or titles containing `dataset`, `data`, `corpus`, `archive`,
  `dump`, `warehouse`, `lake`, `parquet`, `sqlite`, `duckdb`, `csv`, `jsonl`,
  or `snapshot`
- body sections with size, rows, schema, license, storage path, sample, or query
  recipes

It reports suggested `dataset migrate-output ... --dry-run` commands. It must
not write manifests.

### Output Migration

`dataset migrate-output <path>` defaults to dry-run. With `--apply`, it creates
one or more `datasets/<slug>/MANIFEST.md` files and leaves the source output in
place. It never copies the actual dataset into the wiki.

### Inventory Linkage

If an inventory record already tracks the same corpus/dataset, link both ways:

- manifest frontmatter `inventory: [inventory/corpora/<slug>.md]`
- inventory record `sources:` or body link to `datasets/<slug>/MANIFEST.md`

This linkage is optional during migration and should not block manifest creation.

## Lint Behavior

Lint should treat missing `datasets/` as a migration opportunity, not
corruption:

- Missing `datasets/` on an existing wiki: suggestion, not critical.
- `lint --fix`: may create `datasets/_index.md` and missing per-dataset
  subdirectory indexes only.
- Output artifacts that look like dataset manifests: suggestion with migration
  commands.
- Lint must never auto-convert outputs, raw files, or inventory records into
  dataset manifests.
