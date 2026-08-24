---
title: "Test Wiki Topic Guide"
schema_state: advisory
created: 2026-01-10
updated: 2026-01-10
summary: "Human-owned topic guide for local vocabulary, relationships, source boundaries, and conventions."
---

# Test Wiki Topic Guide

> This is not a database schema and it does not make existing wiki content invalid.
> It is a human-owned guide for local vocabulary, relationships, source boundaries, and conventions.
> The librarian may propose improvements, but agents should not rewrite this file without explicit approval.

## State

- `schema_state`: `advisory`
- `advisory` means suggestions only.
- Keep this advisory until the librarian's topic-guide suggestions are consistently low-noise.
- `strict` is an advanced, explicit opt-in; it still never permits automatic content rewrites.

## Entity Types

| Type | Meaning |
|------|---------|
| `concept` | Bounded idea or mechanism compiled under `wiki/concepts/`. |
| `topic` | Broad theme or playbook compiled under `wiki/topics/`. |
| `reference` | Curated list, map, standard, or lookup page under `wiki/references/`. |
| `source` | Raw evidence under `raw/`; factual claims should trace back here. |
| `artifact` | Generated output, project file, inventory record, or dataset manifest. |

## Relationship Verbs

- `cites`: article or output cites a raw source.
- `supports`: source or article supports a claim, plan, or decision.
- `contradicts`: source or article conflicts with another claim.
- `supersedes`: newer article/output replaces an older one.
- `depends-on`: artifact or workflow relies on another artifact.
- `implements`: code, output, or project implements a plan.
- `relates-to`: weak relationship used when a stronger verb is not yet justified.

## Source Conventions

- Keep raw sources immutable under `raw/`.
- Compile durable synthesis under `wiki/` with explicit `sources:` frontmatter.
- Keep generated deliverables under `output/`.
- Use inventory for durable tracking state, not factual evidence.
- Use dataset manifests for large, mutable, binary, remote, or query-oriented data.

## Adoption Notes

- Existing articles do not need immediate rewrites to adopt this guide.
- Librarian topic-guide scans should propose changes in `output/schema-proposal-*.md`.
- Promote only the small conventions that fit this topic; delete unused starter rows.
- Prefer staying advisory unless the human explicitly wants stricter convention warnings.
