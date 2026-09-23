---
description: "Export, refresh, verify, or import a comprehensive cross-topic Project Knowledge Checkpoint for a repository, with privacy checks."
argument-hint: "create [<slug>] [--repo <path>] [--audience private|team|public] [--apply] | refresh <bundle> [--apply] | verify <bundle> | import <bundle|repo> --wiki <name>"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git:*), Bash(gh:*), Bash(ls:*), Bash(mkdir:*), Bash(mktemp:*), Bash(cp:*), Bash(mv:*), Bash(rm:*), Bash(date:*), Bash(python3:*), Bash(*llm-wiki:*)
---

## Your task

Manage the Project Knowledge Checkpoints Export: a portable, comprehensive
project handoff synthesized from relevant compiled knowledge across topic wikis,
with mandatory privacy checks. Read
`skills/wiki-manager/references/checkpoints.md` before acting.

This is not a topic export, raw/session dump, or Git publication command.
`create` and `refresh` are dry-run by default. `--apply` authorizes only the
previewed file write—not commit, push, publication, release, or import.

## Resolve and parse

1. Resolve HUB from `${LLM_WIKI_CONFIG_DIR:-$HOME/.config/llm-wiki}/config.json` using normal
   `hub_path`/fallback rules; read `HUB/_index.md` and `HUB/wikis.json`.
2. Parse `create`, `refresh`, `verify`, or `import`; natural “checkpoint/dump
   this project's wiki knowledge into the repo” means `create`.
3. For create, resolve `--repo` or `git rev-parse --show-toplevel`, symlinks,
   revision, remote, and authoritative visibility. Never guess visibility or
   write outside the resolved repository.
4. Resolve the lowercase slug from an explicit value, selected wiki Project,
   or repo name. Ask only if ambiguity changes scope.

Useful flags: `--project <slug>`, primary `--wiki`, repeatable `--with <wiki>`,
`--audience private|team|public`, `--include-archived`, repeatable
`--allow-source <wiki:path>`, repeatable `--allow-finding <id>`, required
`--override-reason "..."` for overrides, and `--apply`.

There is no option to disable privacy scanning.

## Create

### Project packet and selection

Read bounded repo context: README, supplied `WHY.md`/`BRIEF.md`, ADRs,
architecture/operations/security docs, manifests, and explicit seeds. Exclude
`.git`, dependencies, builds, caches, env files, and arbitrary user folders.

Read active topic roots/indexes; select compiled articles and material Ideas,
Projects, plans, and outputs by goal, aliases, decisions, and constraints.
Follow one needed support hop. Archives require `--include-archived`; raw is not
export content.

For each input record topic, wiki-relative path, SHA-256, inclusion reason,
confidence, `public|team|private|unknown` access, and reuse note. Record
material exclusions and gaps.

### Mandatory comprehensive coverage

Default to comprehensive, not executive-summary-only. After orientation retain
tables, requirements, alternatives, phases, operations, risks, validation, and
gaps. Record input words; comprehensive `coverage` needs their total, every
input mapped to a section, and reasoned omissions. Seal rejects knowledge below
20% of selected words. This catches thinness, not quality: deduplicate or reduce
scope rather than over-compress.

### Mandatory semantic privacy minimization

Classify every input before synthesis; unknown or above-audience inputs fail
closed. Exclude raw bodies, sessions/transcripts/events/prompts/feedback,
credentials/cookies/tokens/keys, home paths/usernames/hosts/IPs/temp paths,
adapter artifacts/data-plane locators, personal records, and confidential
repo/organization detail outside the audience. Summarize only what recipients
need; the deterministic scanner cannot detect every confidential decision.

`--allow-source` must name the exact source and include a reason. Never infer a
source or scanner override from general approval.

### Preview

Show exact `docs/knowledge/<slug>/` destination, audience and repo visibility,
project packet/question, selected articles with reasons, source access,
input/expected handoff word counts, exclusions, gaps, section coverage matrix,
planned five files, and overrides. Without `--apply`, stop. This is the complete
workflow preview, not a reduced sample.

Public repos require explicit `public` audience. A local/untracked or
authoritatively private target may default to `private`; unknown visibility
must stop before final copy.

### Stage, seal, and copy

With `--apply`, generate in a private temporary directory outside the tracked
destination:

- `index.md`: entry point, audience, trust, revision, verification/import use;
- `project-knowledge.md`: coherent synthesis in the reference's stable order;
- `sources.md`: stable IDs and portable provenance—never absolute producer paths;
- `checkpoint.json`: schema `llm-wiki/project-knowledge-checkpoint/v1`,
  `checkpoint_id: pending`, created time, audience, project, scope, inputs with
  exact word counts, comprehensive section coverage/omissions, exclusions,
  empty source overrides/files, and gaps.

Do not hand-write `privacy-report.json`. Resolve the bundled helper and run:

```bash
llm-wiki checkpoint seal <staging> --audience <audience> --json
llm-wiki checkpoint verify <staging> --json
```

Forward explicit source/finding overrides and reason to `seal`. It validates
the fixed bundle, hashes files, writes checkpoint ID and
`privacy-report.json`, and scans filenames/content for credentials, identities,
local paths/network data, session metadata, and prompt markers without
printing matches.

On findings, show only category, opaque/relative path, line, message, and ID;
stop before final copy. The user may remove the value or name each exact
finding plus a reason. Seal reruns and records `overridden`, never `passed`.
There is no blanket or stale-ID bypass.

After successful staging verification:

1. Refuse an existing destination unless refresh/replacement was previewed.
2. Copy all five files to the exact destination.
3. Verify the destination again.
4. On failure, remove the new copy or restore the backup.
5. Append a content-free operation entry to the selected topic log, otherwise
   the hub log. Never log source paths or findings.

## Refresh

Verify first. Re-run stored scope and show sources/claims/decisions/gaps/privacy
added, removed, or changed. Detect human edits from attested hashes and never
silently overwrite them; offer staged regeneration, manual merge, or a new
destination. Preserve stable source IDs, then use the same seal/copy/verify
sequence. Without `--apply`, stop after the diff.

## Verify

Run `llm-wiki checkpoint verify <bundle> --json` read-only. Report checkpoint
ID, audience, integrity, `passed|overridden|blocked`, file count, categories,
and override counts—never matched values.

## Import

For a repo/path, pin the exact revision and isolate one
`docs/knowledge/<slug>/` bundle. Verify before reading:

- reject invalid hashes, missing attestation, or `blocked`;
- show `overridden` categories/IDs and require recipient acceptance;
- ingest the five files through bounded collection provenance;
- preserve checkpoint ID, audience, source IDs, trust, and staleness;
- dedupe by checkpoint ID, then path/content hash; and
- treat imports as source evidence, never overwrite/promote local articles,
  Projects, or prior snapshots automatically.

## Report

Report operation, absolute destination, checkpoint ID, audience, privacy and
verification status, override count, source-topic count, source words, handoff
words, retention ratio, and whether files changed. State separately that no
commit, push, publication, or import occurred unless that distinct action was
explicitly requested.
